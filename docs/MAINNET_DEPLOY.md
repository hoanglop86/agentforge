# AgentForge — BSC Mainnet Deploy Prep (Phase 1)

## Phase 2 — DEPLOYED 19/11/2026 ~10:20 VN ✅

VO funded the deployer himself (0,0005 BNB, verified on-chain 10:19 VN);
deploy executed immediately after, season **45 days** per VO's decision
10:15 VN 19/11 (SPEC said 30, testnet was 7 — mainnet is 45).

| Item | Value |
|---|---|
| AgentForge (mainnet) | `0xa65944f2093e6dcfd1d1a7a4f6744f924068f878` — matches predicted address exactly |
| ForgeToken | `0xfd161e706f2b3bb8eda6644302b15502981ae3b8` — matches predicted address exactly |
| Registry | `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` (real Agent ID registry, verified on-chain via `registry()`) |
| Deploy tx | `0x5edd27f4eb00a2fa53d9645277758f0f4c77804fa07722f929175dcc0c11ec34` |
| Block | 134430226, status 1 |
| Gas used | 3,735,649 @ 0.1 gwei = **0,0003735649 BNB** (within the 0,0005 budget) |
| Deployer after | 0,0001264351 BNB left, nonce 1 |
| Season | 3,888,000 s (45 days); `seasonEnd` = 1798946398 = **10:19 VN 03/01/2027** |
| Season pool at deploy | 0 BNB |
| Sourcify | **exact_match** for BOTH contracts (chain 56, verified 19/11) |
| BscScan | https://bscscan.com/address/0xa65944f2093e6dcfd1d1a7a4f6744f924068f878 · https://bscscan.com/address/0xfd161e706f2b3bb8eda6644302b15502981ae3b8 |
| Code sizes | AgentForge 13,778 bytes; ForgeToken 1,816 bytes |
| Smoke tests (view calls, deployer) | `token()` → ForgeToken ✓ · `registry()` → real registry ✓ · `seasonPool()` = 0 ✓ · `freeMinted(VO)` = 0 ✓ |
| Frontend | `frontend/config.js` switched to CHAIN_ID 56 + mainnet AgentForge address (`node --check` OK) |
| SUBMISSION.md | Mainnet + testnet addresses and verify links filled in (§3) |

**REMAINING STEP — mintFree smoke test from VO's Agent wallet:** the
deployer holds no Agent ID, so it cannot `mintFree()` (reverts `NoAgentId`).
VO's Agent wallet (holds 1 Agent ID, `balanceOf` = 1 on the real registry)
must call `mintFree()` via baw (clean preview, value 0) → hero #1, Lv1,
tier 0, power 100; verify `ownerOf(1)` = VO. Gas ~0,000009 BNB. This is
the real proof the mainnet game gates on real Agent IDs. Do NOT repeat the
paid-mint / merge / forge / battle E2E on mainnet with real BNB — already
proven on testnet (docs/TESTNET_E2E.md).

Prepared **19/11/2026 ~10:13 VN**. VO approved mainnet deploy 10:11 VN 19/11
("cứ triển phí 0.2$ đi"). **NO on-chain transaction has been sent in this
phase** — the deployer is unfunded (0 BNB) until VO funds it.

## Deployer (fresh mainnet keypair — never used on testnet)

- Address: `0x41EBbF62BA0013FEcb03854132725Ba06759195E`
- Key file: `~/workspace/agent-id-hackathon/.deployer-key-mainnet` (mode 600).
  **NEVER print the key. Only fund THIS address.**
- Note: a first keypair was generated during prep and its private key appeared
  in a tool output — that keypair (`0xe56F19B820ee52Ee5e57BE9cCCA86bAC0602Ec67`)
  was DISCARDED and must never be funded or used. The key file holds a second,
  freshly generated keypair whose private key was never printed.

## Funding — from VO's Agent (Binance) wallet

Agent wallet `0x14f395059726c3dA2F3e4a1f969c6E61ae844731` holds
**0,00090233 BNB** (verified on-chain 19/11 ~10:13 VN).

| Item | Gas | Cost @ 0.05 gwei (live) | Cost @ 0.1 gwei (cap) |
|---|---|---|---|
| Deploy AgentForge (only contract) | 3,735,649 (testnet actual; forge dry-run est. 4,856,343) | 0,000187 BNB | 0,000374 BNB |
| `wallet send` Agent wallet → deployer | 21,000 | 0,000001 BNB | 0,000002 BNB |
| mintFree smoke test (VO's wallet, not deployer) | ~171,358 | 0,000009 BNB | 0,000017 BNB |

- **Funding ask: send 0,0005 BNB to the deployer.** Covers the deploy at up to
  ~0.1 gwei even on forge's conservative gas estimate (4,856,343 × 0.1 gwei =
  0,000486 BNB). Expected real spend at live 0.05 gwei: ~0,00019 BNB.
- **Shortfall: ZERO.** Agent wallet 0,00090233 − 0,0005 = 0,00040233 BNB left,
  more than enough for the send gas + the mintFree smoke test from VO's wallet.
- Paid-mint smoke test SKIPPED on mainnet (already proven on testnet; costs
  0.005 BNB value). No seed pool — VO decided no seed.

## Deploy script (mainnet variant)

- New: `contracts/script/DeployMainnet.s.sol` — deploys ONLY AgentForge against
  the REAL registry. It `require`s the registry equals
  `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` and refuses any other address.
  Env: `DEPLOYER_PK`, `REGISTRY` (default = real registry),
  `SEASON_DURATION` (default 604800 = 7 days).
- `forge build` passes (exit 0). Dry-run simulation vs live mainnet RPC
  **succeeded, no broadcast**: Chain 56, 1 tx, est. 4,856,343 gas,
  0,00024282 BNB @ 0.05 gwei. Init code contains the real registry address;
  seasonDuration 604800 (0x93a80) confirmed in the calldata.
- **Predicted addresses (deployer nonce 0, deterministic):**
  - AgentForge: `0xa65944f2093e6dcfd1d1a7a4f6744f924068f878`
  - ForgeToken: `0xfd161e706f2b3bb8eda6644302b15502981ae3b8` (CREATE from game, nonce 1)
  - If the deployer nonce is not 0 at deploy time, addresses differ — check the
    broadcast receipt, do not assume these.
- Season: 45 days from deploy (deployed ~10:19 VN 19/11 → ends 10:19 VN
  03/01/2027). **DECIDED 10:15 VN 19/11 by VO: mainnet 45 days**
  (SPEC said 30, prep brief said 7). Deployed with
  `SEASON_DURATION=3888000`.

## Phase-2 deploy command (run only after funding confirmed)

```shell
cd ~/workspace/agent-id-hackathon/contracts
export PATH="$PATH:$HOME/.foundry/bin"
RPC=https://bsc-dataseed.binance.org
DEPLOYER_PK=$(cat ../.deployer-key-mainnet)
SEASON_DURATION=604800 DEPLOYER_PK=$DEPLOYER_PK \
  forge script script/DeployMainnet.s.sol --rpc-url $RPC --broadcast \
  --with-gas-price 100000000 --priority-gas-price 100000000 --start-fresh
# --with-gas-price 0.1 gwei caps the deploy at ~0.00049 BNB even on forge's
# high estimate. Mainnet baseFee is live (unlike testnet's 0), so forge's own
# estimate is sane — the explicit caps are a spike guard only.
# Record: AgentForge, ForgeToken (= token()), tx hash, block, gas used.
```

## Verification (Sourcify v2, chain 56, no API key)

```shell
forge verify-contract <AGENT_FORGE> src/AgentForge.sol:AgentForge \
  --chain-id 56 --verifier sourcify --rpc-url $RPC
forge verify-contract <FORGE_TOKEN> src/ForgeToken.sol:ForgeToken \
  --chain-id 56 --verifier sourcify --rpc-url $RPC
# Check: https://sourcify.dev/server/v2/contract/56/<addr>?fields=abi returns 200.
# BscScan picks Sourcify verification up automatically.
# NOTE: do NOT verify any MockAgentIdRegistry on mainnet — none is deployed.
```

## Smoke test (after deploy, before announcing)

Deployer holds **no Agent ID** (registry `balanceOf(deployer)` = 0, verified),
so the deployer CANNOT call `mintFree()` — it reverts `NoAgentId`. Smoke
tests split by wallet:

1. Deployer / anyone (view calls, free):
   - `token()` → ForgeToken address; `registry()` → `0x60B9…22F` ✓
   - `seasonPool()` = 0; `seasonEnd()` = deploy time + 604800
   - `freeMinted(VO)` = 0 before VO mints.
2. VO's Agent wallet (holds 1 Agent ID — `balanceOf(VO)` = 1 on the real
   registry, verified 19/11): `mintFree()` via baw (clean preview, value 0)
   → hero #1, level 1, tier 0, power 100; `ownerOf(1)` = VO. Gas ~0,000009 BNB.
   This is the real proof the mainnet game gates on real Agent IDs.
3. Do NOT repeat the paid-mint / merge / forge / battle E2E on mainnet with
   real BNB — already proven on testnet (docs/TESTNET_E2E.md). The first real
   users will exercise those paths; watch the first mints/battles instead.

## Frontend switch (after deploy + verify)

`frontend/config.js`:
- `CHAIN_ID: 56` (was 97), `AGENT_FORGE_ADDRESS: "<mainnet AgentForge>"`.
- `AGENT_ID_REGISTRY_MAINNET` already correct
  (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`).
- `node --check frontend/config.js` after edit. Registry + token are read
  on-chain from the game contract — no other file changes.
- Keep the testnet address in a comment for reference (as now).

## SUBMISSION.md placeholders to fill (after mainnet deploy)

- Repo URL (needs VO/parent to provide the public repo link).
- Demo URL (frontend hosting — not yet hosted).
- Mainnet contract addresses + Sourcify/BscScan verify links (AgentForge,
  ForgeToken). Testnet addresses already documented in TESTNET_DEPLOY.md.
- Season start/end dates (from the real deploy).

## Blockers / open items

- **None for the deploy itself.** Funding shortfall is zero; script dry-run
  passes; real registry verified exact_match on Sourcify (ERC721, 8,756 bytes
  code) and VO holds 1 Agent ID on it.
- Open decision RESOLVED: season is 45 days (VO 10:15 VN 19/11), deployed.
- Browser UI test still pending (subagent has no browser) — separate work.
- Distribution to 30+ real Agent ID holders (Boltbook/Telegram listing) is
  post-deploy work, not part of this phase.
- AgentForge has NO owner-only functions (grep: no `onlyOwner` in the
  contract) — no admin backdoor; owner is set in the constructor only.
