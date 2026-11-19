# AgentForge — BSC Testnet Deploy Runbook

Status (18/11 ~21:40 VN): **BLOCKED — deployer wallet has 0 tBNB.**
Everything else is ready: contracts 30/30 tests pass, deploy script
dry-run-simulated OK against live testnet RPC, gas estimated.

## 0. Wallets (testnet only, no real value)

| Wallet | Address | Key file (mode 600) |
|---|---|---|
| Deployer / Tester 1 | `0x7455764740784BbFa3Fd165c16eFfA0E396Cd5CA` | `~/workspace/agent-id-hackathon/.deployer-key-testnet` |
| Tester 2 | _create in step 2 below_ | `~/workspace/agent-id-hackathon/.tester2-key-testnet` |

**Never print the key files. Never use them on mainnet. Never use VO's keys.**

## 1. UNBLOCK: get tBNB (needs a human + browser — subagent cannot do this)

Faucets tried by the deploy agent (18/11, all via curl/API):
- Official `https://testnet.bnbchain.org/faucet-smart` — **hCaptcha required** (confirmed
  in page HTML: `js.hcaptcha.com/1/api.js`), plus the address must hold
  ≥0.002 BNB on BSC mainnet — the fresh deployer holds 0, so it may be
  rejected even after captcha. JS chunk 502s from curl.
- `https://faucet.zalalena.com/bsc` — **captcha required**, but explicitly
  **no login / no balance needed**, 10 claims/day, 60-min cooldown.
  → **Try this one first in a browser.**
- Chainstack faucet API — needs API key + 0.08 ETH on Ethereum mainnet. No.
- QuickNode / Alchemy / Crypto Chief / Google Cloud faucets — need accounts/API keys. No.
- Chainlink faucet — needs browser wallet-connect. Possible fallback in browser.

**Human step:** open https://faucet.zalalena.com/bsc (fallback:
https://testnet.bnbchain.org/faucet-smart), paste the deployer address
`0x7455764740784BbFa3Fd165c16eFfA0E396Cd5CA`, solve captcha, claim.
Official faucet pays **0.3 tBNB / 24h** — enough for the whole plan below.

Check funding:
```shell
export PATH="$PATH:$HOME/.foundry/bin"
RPC=https://bsc-testnet.publicnode.com   # official seed (data-seed-prebsc-1-s1) times out from this VM; publicnode works
cast balance 0x7455764740784BbFa3Fd165c16eFfA0E396Cd5CA --rpc-url $RPC
```

**Budget (gas price on testnet ~0.13 gwei at check time):**
- Deploy MockRegistry + AgentForge: ~6,156,218 gas ≈ **0.0008 tBNB** (0.018 at 3 gwei, 0.031 at 5 gwei)
- E2E instance 1: paid mints 0.04 + battle bets 0.002 + ~25 tx gas ≈ 0.045 tBNB
- E2E instance 2 (short season): same again ≈ 0.045 tBNB
- **Total < 0.1 tBNB → one 0.3 tBNB faucet drip covers everything.**

## 2. Deploy (once funded)

```shell
cd ~/workspace/agent-id-hackathon/contracts
export PATH="$PATH:$HOME/.foundry/bin"
RPC=https://bsc-testnet.publicnode.com
DEPLOYER_PK=$(cat ../.deployer-key-testnet)

# Main 7-day instance
SEASON_DURATION=604800 DEPLOYER_PK=$DEPLOYER_PK \
  forge script script/Deploy.s.sol --rpc-url $RPC --broadcast
# Record: MockAgentIdRegistry, AgentForge, ForgeToken (= token()), tx hashes, block numbers.
# (Script prints all three addresses + seasonEnd.)

# Tester-2 wallet
cast wallet new   # save address + key to ../.tester2-key-testnet, chmod 600, NEVER print the key
# Fund tester 2 with 0.05 tBNB from deployer:
cast send <TESTER2_ADDR> --value 0.05ether --private-key $DEPLOYER_PK --rpc-url $RPC
```

## 3. Verify (Sourcify, no API key needed)

```shell
forge verify-contract <AGENT_FORGE> src/AgentForge.sol:AgentForge \
  --chain-id 97 --verifier sourcify --rpc-url $RPC
forge verify-contract <MOCK_REGISTRY> src/MockAgentIdRegistry.sol:MockAgentIdRegistry \
  --chain-id 97 --verifier sourcify --rpc-url $RPC
forge verify-contract <FORGE_TOKEN> src/ForgeToken.sol:ForgeToken \
  --chain-id 97 --verifier sourcify --rpc-url $RPC
# BscScan testnet verify needs an API key — try only if a key is available;
# Sourcify links: https://testnet.bscscan.com/address/<addr>#code (after Sourcify verify
# BscScan picks it up) or https://sourcify.dev/#/lookup/<addr>
```

## 4. E2E — instance 1 (7-day season)

```shell
GAME=<AGENT_FORGE>; REG=<MOCK_REGISTRY>; TOKEN=<FORGE_TOKEN>
KEY1=$DEPLOYER_PK; KEY2=$(cat ../.tester2-key-testnet)
A1=0x7455764740784BbFa3Fd165c16eFfA0E396Cd5CA; A2=<TESTER2_ADDR>

# --- Mock Agent ID ---
cast send $REG "mintSelf()" --private-key $KEY1 --rpc-url $RPC
cast call $REG "balanceOf(address)(uint256)" $A1 --rpc-url $RPC   # expect 1

# --- Free mints x2 (wallet 1) ---
cast send $GAME "mintFree()" --private-key $KEY1 --rpc-url $RPC   # token 1
cast send $GAME "mintFree()" --private-key $KEY1 --rpc-url $RPC   # token 2
cast call $GAME "heroOf(uint256)(uint8,uint8,uint256)" 1 --rpc-url $RPC  # expect level 1, tier 0, power 100
cast call $GAME "freeMinted(address)(uint256)" $A1 --rpc-url $RPC       # expect 2
cast call $GAME "mintFree()" --from $A1 --rpc-url $RPC        # expect revert FreeMintExhausted (3rd free, simulated)

# --- Paid mints x8 = 0.04 tBNB ---
cast send $GAME "mintPaid(uint256)" 8 --value 0.04ether --private-key $KEY1 --rpc-url $RPC  # tokens 3..10
cast call $GAME "mintCountOf(address)(uint256)" $A1 --rpc-url $RPC   # expect 10
cast call $GAME "seasonPool()(uint256)" --rpc-url $RPC                # expect 0.04 ether

# --- Merge chain 1..10 -> Lv10 (token 19) ---
for pair in "1 2" "11 3" "12 4" "13 5" "14 6" "15 7" "16 8" "17 9" "18 10"; do
  set -- $pair; cast send $GAME "merge(uint256,uint256)" $1 $2 --private-key $KEY1 --rpc-url $RPC
done
# new ids: 11(Lv2) 12(Lv3) 13(Lv4) 14(Lv5) 15(Lv6) 16(Lv7) 17(Lv8) 18(Lv9) 19(Lv10)
cast call $GAME "heroOf(uint256)(uint8,uint8,uint256)" 19 --rpc-url $RPC  # expect level 10, tier 0, power 325

# --- Forge Lv10 -> tiered (token 20) ---
cast send $GAME "forge(uint256)" 19 --private-key $KEY1 --rpc-url $RPC
cast call $GAME "heroOf(uint256)(uint8,uint8,uint256)" 20 --rpc-url $RPC  # level 10, tier 1..4 (roll)
cast call $GAME "weightOf(uint8)(uint256)" <TIER> --rpc-url $RPC         # 1/5/20/100 per SPEC
# forgeCount: cast call $GAME "forgeCount(uint8)(uint256)" <TIER> -> 1

# --- Battle: wallet 2 mints Agent ID + 2 free heroes (tokens 21, 22) ---
cast send $REG "mintSelf()" --private-key $KEY2 --rpc-url $RPC
cast send $GAME "mintFree()" --private-key $KEY2 --rpc-url $RPC
cast send $GAME "mintFree()" --private-key $KEY2 --rpc-url $RPC
# Wallet 1 creates battle with tiered Lv10 (token 20), bet 0.001
cast send $GAME "createBattle(uint256)" 20 --value 0.001ether --private-key $KEY1 --rpc-url $RPC  # battleId 1
# Wallet 2 accepts with Lv1 hero (token 21), same bet
cast send $GAME "acceptBattle(uint256,uint256)" 1 21 --value 0.001ether --private-key $KEY2 --rpc-url $RPC
# Checks:
cast call $GAME "battleInfo(uint256)" 1 --rpc-url $RPC   # status 1=RESOLVED, winner recorded
cast call $GAME "ownerOf(uint256)(address)" 20 --rpc-url $RPC  # back with A1
cast call $GAME "ownerOf(uint256)(address)" 21 --rpc-url $RPC  # back with A2
cast call $TOKEN "balanceOf(address)(uint256)" <WINNER> --rpc-url $RPC  # winner +1000 FORGE
cast call $GAME "seasonPool()(uint256)" --rpc-url $RPC  # expect 0.04 + 0.0001 = 0.0401 ether
```

## 5. E2E — instance 2 (short season, 600s)

```shell
# Deploy 2nd AgentForge (same registry) with 600s season
SEASON_DURATION=600 DEPLOYER_PK=$DEPLOYER_PK \
  forge script script/Deploy.s.sol --rpc-url $RPC --broadcast
GAME2=<AGENT_FORGE_2>
# Repeat on GAME2 with wallet 1: mintSelf already done (registry is shared),
# mintFree x2, mintPaid(8) 0.04 tBNB, merge chain -> Lv10, forge -> tiered token.
# (Token ids restart at 1 on the new contract; merge/forge ids follow the same pattern.)
# Optional: one battle on GAME2 (needs wallet 2 heroes on GAME2 too) to test the 5% fee there.
# Wait until seasonEnd, then:
cast call $GAME2 "seasonEnd()(uint256)" --rpc-url $RPC
cast send $GAME2 "snapshotSeason()" --private-key $KEY1 --rpc-url $RPC
cast call $GAME2 "snapshotPool()(uint256)" --rpc-url $RPC        # expect 0.04 ether (+0.0001 if battled)
cast call $GAME2 "snapshotTotalWeight()(uint256)" --rpc-url $RPC # expect = weight of the single tier NFT
# Claim: expected amount = snapshotPool * weight / totalWeight (= full pool if only one tier NFT)
cast send $GAME2 "claimSeasonReward(uint256)" <TIER_TOKEN_ID> --private-key $KEY1 --rpc-url $RPC
cast call $GAME2 "seasonClaimed(uint256)(bool)" <TIER_TOKEN_ID> --rpc-url $RPC  # expect true
# Second claim must revert AlreadyClaimed.
```

## 6. Frontend config + read checks

```shell
# Fill frontend/config.js: AGENT_FORGE_ADDRESS = <AGENT_FORGE instance 1>, keep CHAIN_ID 97.
node --check frontend/config.js
# Read checks the app uses (all must return sane values on the deployed address):
cast call $GAME "freeMinted(address)(uint256)" $A1 --rpc-url $RPC
cast call $GAME "mintCountOf(address)(uint256)" $A1 --rpc-url $RPC
cast call $GAME "seasonPool()(uint256)" --rpc-url $RPC
cast call $GAME "seasonEnd()(uint256)" --rpc-url $RPC
cast call $GAME "token()(address)" --rpc-url $RPC
cast call $GAME "registry()(address)" --rpc-url $RPC
cast call $GAME "battleInfo(uint256)" 1 --rpc-url $RPC
# Browser test of the actual UI still needed afterwards (subagent has no browser).
```

## 7. Notes / gotchas found during prep (18/11)

- `forge test`: **30/30 pass** (incl. `test_WeightOf_MatchesSpec` — weightOf is
  Uncommon 1 / Rare 5 / Mythic 20 / Legendary 100 per SPEC; the README line
  "Season weight: Uncommon 12, Rare 15..." actually describes the power
  multipliers, not weights — contract is correct, no change needed).
- Official BSC testnet RPC `data-seed-prebsc-1-s1.bnbchain.org:8545` **times out
  from this VM** (135s); `https://bsc-testnet.publicnode.com` works
  (chain 97, block ~143,464,543 at check time). Use publicnode for all steps.
- Deploy script dry-run simulation OK: 6,156,218 gas for both deploys.
- Testnet gas price at check: ~0.126 gwei (very cheap).
- Deploy script: `contracts/script/Deploy.s.sol` (`SEASON_DURATION` env, default 604800).
