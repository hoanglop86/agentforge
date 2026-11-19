# AgentForge

A free-to-play hero-battling game on BNB Chain for wallets holding a Binance
`.ai` **Agent ID**. Entry to the **Binance Agent ID Hackathon** (Binance Wallet
× BNB Chain; submission deadline 15:00 VN, 9 December 2026).

Each Agent ID wallet mints **2 hero NFTs free** (gas only). Merge two heroes
into one higher-level hero, up to Lv10, then forge a Lv10 hero into a tiered
NFT — **Legendary (cap 100), Mythic (500), Rare (5,000), or Uncommon**.
Heroes battle head-to-head in PvP for a BNB pot plus $FORGE tokens, and tiered
heroes share the end-of-season reward pool, weighted by tier. The season pool
is funded entirely by paid mints and a 5% cut of battle pots — there is no
dev cut.

**Live:** [Boltbook](https://boltbook.fun/alphapedia/agentforge) ·
Demo URL: _pending hosting — see `docs/SUBMISSION.md`_

> Rewards are not guaranteed: battle outcomes are probabilistic and the
> season pool depends on paid mints and battle activity. No profit is
> promised anywhere in the game or the UI.

## How it works

| Action | Cost | Notes |
| --- | --- | --- |
| `mintFree()` | gas only | 2 free per wallet, Agent ID holders only |
| `mintPaid(n)` | 0.005 BNB each | max 10 mints per wallet total; funds the pool |
| Merge 2 heroes | gas only | burn two → one hero at `max(lvA, lvB) + 1`, max Lv10 |
| Forge Lv10 hero | gas only | tier roll Legendary 1% / Mythic 5% / Rare 20% / Uncommon 74%, hard caps enforced with downgrade |
| PvP battle | 0.001–0.05 BNB bet per side | winner takes 95% of the pot + 1,000 FORGE; 5% to the pool; loser keeps their hero |
| Season claim | gas only | tiered heroes claim a weighted share (Uncommon 1 / Rare 5 / Mythic 20 / Legendary 100) |

Power = `100 + 25 × (level − 1)`, times the tier multiplier
(Uncommon ×1.2 / Rare ×1.5 / Mythic ×2 / Legendary ×3). Battle win chance
is the honest `powerA / (powerA + powerB)`, resolved on-chain.

Agent ID is the access gate, not a checkbox: minting checks the on-chain
Agent ID registry (`balanceOf(msg.sender) > 0`) — no off-chain allowlist, no
way to mint without holding an Agent ID. No QR login, no seed phrase or
private key is ever requested; every action is a normal wallet transaction
the user reviews and confirms.

## Contracts

| Contract | Mainnet (chain 56) | Testnet (chain 97) |
| --- | --- | --- |
| AgentForge (ERC721 `AgentForge Hero`, AFHERO) | [0xa65944f2093e6dcfd1d1a7a4f6744f924068f878](https://bscscan.com/address/0xa65944f2093e6dcfd1d1a7a4f6744f924068f878) | [0x69Fd48117Ec4f920501B573096133fefEA2c6096](https://testnet.bscscan.com/address/0x69Fd48117Ec4f920501B573096133fefEA2c6096) |
| ForgeToken (ERC20 `FORGE`, 1,000,000,000 fixed supply) | [0xfd161e706f2b3bb8eda6644302b15502981ae3b8](https://bscscan.com/address/0xfd161e706f2b3bb8eda6644302b15502981ae3b8) | [0x79A82C7a2234e34E1108665Bbc9EBC6Ef1aCe710](https://testnet.bscscan.com/address/0x79A82C7a2234e34E1108665Bbc9EBC6Ef1aCe710) |
| Agent ID registry | [0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F](https://bscscan.com/address/0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F) (real) | [0x4315F61dE24A1e7B0fA0199CF49Be742432D7dcd](https://testnet.bscscan.com/address/0x4315F61dE24A1e7B0fA0199CF49Be742432D7dcd) (MockAgentIdRegistry, testnet-only) |

- **Mainnet:** deployed 19/11/2026, 45-day season ends 10:19 VN 03/01/2027.
  Deploy tx
  [0x5edd27f4eb00a2fa53d9645277758f0f4c77804fa07722f929175dcc0c11ec34](https://bscscan.com/tx/0x5edd27f4eb00a2fa53d9645277758f0f4c77804fa07722f929175dcc0c11ec34),
  3,735,649 gas @ 0.1 gwei. Sourcify **exact_match** (creation + runtime)
  for both contracts. First mainnet hero (#102) minted free 19/11/2026.
- **Testnet:** deployed 19/11/2026, 7-day season. Full end-to-end test
  passed (free/paid mint, merge to Lv10, forge to Uncommon and Rare,
  battles, season snapshot and pool claim) — see `docs/TESTNET_E2E.md`.
- **Tests:** Foundry suite, **30/30 passing** (free-mint gating, paid mint
  and pool accounting, merge levels, forge caps and downgrade, battle
  escrow/payout/cancel, season snapshot and claim math, double-claim
  revert).

## Layout

```
SPEC.md                  Full game spec
TESTNET_RUNBOOK.md       Testnet deploy + E2E runbook
contracts/               Foundry project (Solidity 0.8.24, OpenZeppelin v5.7.0)
  src/AgentForge.sol     ERC721 heroes + all game logic
  src/ForgeToken.sol     ERC20 FORGE, fixed supply, minted once to the game
  src/MockAgentIdRegistry.sol  Testnet-only registry stand-in
  test/AgentForge.t.sol  30 tests
  script/Deploy.s.sol / DeployMainnet.s.sol
frontend/                Static single-page app (index.html, app.js, config.js, abi/)
  index.html             Connect wallet, Mint, My Heroes, Merge, Forge, Battle, Pool & Season
docs/                    SUBMISSION.md, deploy records, E2E records, marketing prep
```

## Build & test

Requires [Foundry](https://getfoundry.sh/) (`forge`, `cast`).

```shell
cd contracts
forge build
forge test -vvv        # 30/30 passing
```

## Deploy

Deploy scripts read the deployer key from the environment only — keys are
**never** stored in the repo (see `.gitignore`).

```shell
cd contracts
# Testnet (7-day season)
DEPLOYER_PK=$(cat ../.deployer-key-testnet) SEASON_DURATION=604800 \
  forge script script/Deploy.s.sol --rpc-url <testnet-rpc> --broadcast
# Mainnet (45-day season; real registry is the default, other registries are refused)
DEPLOYER_PK=$(cat ../.deployer-key-mainnet) SEASON_DURATION=3888000 \
  forge script script/DeployMainnet.s.sol --rpc-url <mainnet-rpc> --broadcast
```

See `TESTNET_RUNBOOK.md` and `docs/MAINNET_DEPLOY.md` for the exact
commands and records. Verify on Sourcify after deploy
(`?fields=abi` on the v2 API; `exact_match` expected).

## Frontend

Static site, no build step, no backend. `config.js` already points at the
mainnet contract; serve the `frontend/` directory (or open `index.html`
directly) and connect an injected wallet (MetaMask / Binance Wallet
extension). Ethers v6 is loaded from CDN.

## Submission

Hackathon brief: `docs/SUBMISSION.md`. Official announcement:
[Binance — Agent ID Hackathon](https://www.binance.com/en/support/announcement/detail/95f5dbe0ea674a48a739b59e046648bf).
Submission period 2026-11-18 08:00 UTC to 2026-12-09 08:00 UTC. Each team
may submit one project only. Prize eligibility needs a live product with
≥30 Agent ID addresses interacting with the submitted contract(s) during
the Submission Period.

## License

MIT — see [LICENSE](LICENSE).
