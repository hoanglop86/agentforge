# AgentForge — Agent ID Hackathon Build Spec

Project: **AgentForge** (NFT game for Binance Agent ID holders).
Hackathon: Binance Agent ID Hackathon (Binance Wallet × BNB Chain). Submission deadline **15:00 VN 09/12/2026**.
Prizes: 60.000 USDC (Pioneer 29.000 by on-chain metrics + Innovation 29.000 by panel; each needs ≥30 interacting Agent ID addresses; top-20 winning projects get a 2-char Agent ID claim spot).
Requirements: contracts on BNB Chain, verified + open-source on BscScan, product genuinely uses Agent ID (access control).

## VO's spec (20:51 VN 18/11)
- Mint NFT FREE, only Agent ID holders, 2 free/wallet.
- Use NFT to PvP for rewards: project token + BNB pool (pool funded by paid extra mints).
- Merge 2 NFTs → 1 higher-level NFT, max Lv10.
- At Lv10, forge into a higher-tier NFT: Legendary (LG) max 100, Mythic 500, Rare 5.000, rest Uncommon, NO Common. Higher tier = bigger share of end-of-season reward pool.
- Pool from paid mints feeds the end-of-season pool and/or per-win rewards.

## Design decisions (coordinator)
- **All mints (free + paid) require Agent ID** (registry `balanceOf(msg.sender) > 0`). Registry is a constructor param: mainnet = `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`; testnet = `MockAgentIdRegistry` (deployed alongside, anyone can mint a test Agent ID).
- **Merge rule:** burn two tier-NONE NFTs owned by caller → mint one tier-NONE NFT with `level = max(levelA, levelB) + 1`, capped at 10. Merge requires `max(levelA, levelB) < 10` (Lv10 uses forge instead). This makes Lv10 reachable with 10 base NFTs (not 512).
- **Forge:** burn a Lv10 tier-NONE NFT → mint a tier NFT (level 10, tier rolled). Tier roll: pseudo-random `keccak256(block.prevrandao, block.number, msg.sender, tokenId, forgeNonce)` with weights Legendary 1% / Mythic 5% / Rare 20% / Uncommon 74%, **hard caps enforced** (LG 100, Mythic 500, Rare 5.000); if the rolled tier is exhausted, downgrade to the next available tier. Uncommon uncapped. Tier NFTs cannot merge (forge is the endgame); they can battle.
- **Power:** base `100 + 25*(level-1)`; tier multiplier: Uncommon ×1.2, Rare ×1.5, Mythic ×2, Legendary ×3. Win probability = `powerA / (powerA + powerB)`, shown honestly on the frontend.
- **Battle (real 2-player):** `createBattle(tokenId)` payable (bet 0.001–0.05 BNB), NFT escrowed in contract. `acceptBattle(battleId, tokenId)` payable (same bet), NFT escrowed, resolves immediately: winner gets 95% of the pot, 5% goes to the season pool, winner also gets 1.000 $FORGE. Both NFTs returned to owners (loser does NOT lose their NFT — only the bet is at stake). `cancelBattle` (creator, while OPEN) refunds bet + NFT. Self-accept and double-battle forbidden.
- **$FORGE token:** ERC20 `AgentForge` / `FORGE`, 18 decimals, fixed supply 1.000.000.000, minted to the game contract (game contract deploys the token in its constructor). No further minting.
- **Season pool (accounting variable `seasonPool`, NOT raw balance):** funded by 100% of paid-mint revenue + 5% of each battle pot. No dev cut. Season length = constructor param (mainnet 30 days; testnet 7 days for demo). After `seasonEnd`, anyone calls `snapshotSeason()` once (snapshots pool + total tier weight); each tier NFT claims `weight / totalWeight * snapshotPool` via `claimSeasonReward(tokenId)` (pull pattern, one claim per token). **Tier weights (exact, hard-coded in `weightOf`): Uncommon 1, Rare 5, Mythic 20, Legendary 100.** (NOT the power multipliers 1.2/1.5/2/3 — never derive season weights from power.) Only tier NFTs (Uncommon+) share the season pool; base NFTs earn battle rewards only.
- **Paid mint:** 0,005 BNB each, max 10 mints/wallet total (2 free + 8 paid). MAX_SUPPLY base NFTs = 10.000.
- **Randomness:** prevrandao-based pseudo-random (NOT Chainlink VRF — out of scope). Document honestly; frontend shows probabilities, never guarantees a win.

## Contracts (`contracts/`)
- `AgentForge.sol` — ERC721 `AgentForge Hero` (AFHERO) + all game logic (mint/merge/forge/battle/season). Constructor: `(address registry, uint256 seasonDuration)`.
- `ForgeToken.sol` — ERC20 fixed supply, minted to game contract.
- `MockAgentIdRegistry.sol` — testnet only, minimal ERC721, public mint for testing.
- Key functions: `mintFree()`, `mintPaid(uint256)`, `merge(uint256,uint256)`, `forge(uint256)`, `createBattle(uint256)`, `acceptBattle(uint256,uint256)`, `cancelBattle(uint256)`, `snapshotSeason()`, `claimSeasonReward(uint256)`, views `levelOf`, `tierOf`, `powerOf`, `freeMinted`, `mintCountOf`, `seasonPool`, `seasonEnd`, `forgeCount(Tier)`, `battleInfo`, `token()`.
- Events for everything: Mint, Merge, Forge, BattleCreated, BattleResolved, BattleCancelled, SeasonSnapshot, SeasonRewardClaimed.

## Frontend (`frontend/`)
Static `index.html` + `app.js`, ethers v6 via CDN. Injected-wallet connect only (MetaMask/Binance Wallet extension). **NO QR login, NO Agentic Wallet web login, NO secrets.** Sections: Mint, My Heroes, Merge, Forge, Battle (open list + create/accept), Pool & Season. Copy: NO profit promises anywhere; show win probabilities; "rewards are not guaranteed".

## Testing & deploy
- Foundry (preferred if installed) or Hardhat. Full test suite, `forge test` must pass: free-mint gating, paid mint + pool accounting, merge levels, forge caps + downgrade, battle escrow/payout/cancel, season snapshot + claim math + double-claim revert.
- Deploy BSC **testnet (97)** first, verify Sourcify/BscScan testnet, end-to-end test (mock Agent ID → free mint → merge → forge → battle → season).
- **Mainnet ONLY after parent approval + BNB top-up.** VO's wallet has ~0,0013 BNB — not enough. Report gas estimate to parent BEFORE any mainnet deploy. Never self-deploy mainnet.

## Red lines (hard)
- No Binance brand impersonation in name/domain. No web QR login for Agentic Wallet. No bypassing user tx confirmation. No unauthorized transfers. No collecting seed phrases/private keys/API secrets/pairing codes. No profit promises ("passive income" etc. banned). No packaging Agent ID as a tool to look up other people's wallets by name. No wash volume / fake accounts.
- Never ask VO to paste a secret/key.

## Submission brief (`docs/SUBMISSION.md`)
Short: what the project is, where Agent ID is used, plan to reach 30+ interacting holders (free-mint distribution via Boltbook/Telegram free-mint channels, 2 free/wallet, PvP + season pool incentives).

## Milestones (report to parent at each)
1. Contracts + tests pass (+ ABI).
2. Frontend runnable.
3. Testnet deployed + verified + e2e tested.
