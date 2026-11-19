# AgentForge — Agent ID Hackathon Submission

**Hackathon:** Binance Agent ID Hackathon (Binance Wallet × BNB Chain)
**Submission deadline:** 15:00 VN, 9 December 2026
**Team:** VO (ganggangtrader.ai)
**Repository:** [TODO: public repo URL — tree prepared 19/11/2026 (`.gitignore` + `README.md` + `LICENSE` MIT in the workdir); `gh` is not authenticated on this machine, so the repo cannot be created/pushed from here yet]
**Live demo:** [TODO: demo URL — frontend hosting in progress 19/11/2026; testnet deployment is DONE (see §3), only hosting is pending]

## 0. Submission process — status 19/11/2026 (facts only, nothing submitted yet)

- Official announcement:
  <https://www.binance.com/en/support/announcement/detail/95f5dbe0ea674a48a739b59e046648bf>
  (also on Binance Square). Submission Period **2026-11-18 08:00 UTC to
  2026-12-09 08:00 UTC** (15:00 VN 09/12/2026). Internal Review
  09–17/12, Public Review 17–20/12. Each team may submit **one project
  only**. Rewards go to the "reward receiving address provided during
  project submission".
- What the announcement requires submitters to provide: project name,
  website, contract address(es), Agent ID usage description, "and other
  required materials". Contracts must be deployed on BNB Chain with source
  verified and open-sourced on BscScan. No registration needed.
- **The announcement publishes NO dedicated project-submission form link.**
  The only survey link in the announcement is the **X-promotion**
  (Agent Ecosystem Promotion Award) survey:
  <https://app.binance.com/uni-qr/user-survey/ff6832f8d2984af289068c9450a3c98c>
  — that survey is for submitting X post links, NOT project entries. Do
  NOT submit the project there.
- **Still to be located:** the project-submission form/survey URL. It was
  not found in the announcement, the Square post, or web search on
  19/11/2026. Likely channels: a @BinanceWallet / BNB Chain post, or a
  follow-up in the announcement. Precedent from the September 2026 Binance
  Agent OS Mini Hackathon: project entries went through a Binance survey
  (`app.binance.com/uni-qr/user-survey/<id>`, Binance login required) plus
  a public GitHub repo — but that survey ID belongs to a different
  hackathon and must NOT be reused.
- Prize eligibility (per announcement): product live with **≥30 Agent ID
  addresses** interacting with the submitted contract(s) during the
  Submission Period. Currently 1 (VO's hero #102 minted 19/11/2026);
  distribution is via the live Boltbook listing
  (<https://boltbook.fun/alphapedia/agentforge>) and the demo site once
  hosted.

---

## 1. Project overview

AgentForge is an on-chain NFT game built for Binance Agent ID holders. Every
player starts by minting a free Hero NFT (2 free per wallet, Agent ID holders
only). Heroes level up by merging two into one (up to Lv10); a Lv10 Hero can
be forged into a tiered Hero — Legendary (cap 100), Mythic (cap 500), Rare
(cap 5,000), or Uncommon (uncapped). Heroes battle head-to-head in PvP for a
BNB pot plus $FORGE tokens, and tiered Heroes share the end-of-season reward
pool, weighted by tier. The season pool is funded entirely by paid mints and
a 5% cut of battle pots — there is no dev cut.

## 2. How Agent ID is used

Agent ID is the access gate for the whole game, not a checkbox:

- **Minting requires a real Agent ID.** Both `mintFree()` and `mintPaid()`
  check the on-chain registry: `balanceOf(msg.sender) > 0` reverts otherwise.
  The check reads the Agent ID registry contract directly; there is no
  off-chain allowlist and no way to mint without holding an Agent ID.
- **The NFT is the credential for everything after minting.** Merge, forge,
  battle, and season claims all operate on Hero NFTs. Without an Agent ID
  you cannot mint, and without a Hero you cannot play any part of the game.
- **Mainnet registry:** `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`
  (constructor parameter, not hard-coded).
- **Testnet:** a `MockAgentIdRegistry` stands in for the real registry so
  anyone can mint a test Agent ID and try the full game loop on BSC testnet.
  It is testnet-only and is never used on mainnet.

## 3. Contracts

| Contract | What it is |
|---|---|
| `AgentForge.sol` | ERC721 `AgentForge Hero` (AFHERO) + all game logic: mint, merge, forge, battle, season |
| `ForgeToken.sol` | ERC20 `AgentForge` / `FORGE`, fixed supply 1,000,000,000, minted once to the game contract; no further minting |
| `MockAgentIdRegistry.sol` | Testnet-only stand-in Agent ID registry (public test mint) |

- **BSC testnet (chain 97) — DEPLOYED 19/11/2026, E2E passed:**
  - AgentForge: 0x69Fd48117Ec4f920501B573096133fefEA2c6096
  - ForgeToken: 0x79A82C7a2234e34E1108665Bbc9EBC6Ef1aCe710
  - MockAgentIdRegistry: 0x4315F61dE24A1e7B0fA0199CF49Be742432D7dcd
  - Verification: Sourcify exact_match for all three (see docs/TESTNET_DEPLOY.md, docs/TESTNET_E2E.md). Season 7 days, ends 06:42 VN 26/11/2026.
- **BSC mainnet (chain 56) — DEPLOYED 19/11/2026:**
  - AgentForge: 0xa65944f2093e6dcfd1d1a7a4f6744f924068f878
    - BscScan: https://bscscan.com/address/0xa65944f2093e6dcfd1d1a7a4f6744f924068f878
    - Sourcify: https://sourcify.dev/server/v2/contract/56/0xa65944f2093e6dcfd1d1a7a4f6744f924068f878 (exact_match)
    - Deploy tx: 0x5edd27f4eb00a2fa53d9645277758f0f4c77804fa07722f929175dcc0c11ec34, block 134430226, gas 3,735,649 @ 0.1 gwei = 0.0003735649 BNB
  - ForgeToken: 0xfd161e706f2b3bb8eda6644302b15502981ae3b8
    - BscScan: https://bscscan.com/address/0xfd161e706f2b3bb8eda6644302b15502981ae3b8
    - Sourcify: https://sourcify.dev/server/v2/contract/56/0xfd161e706f2b3bb8eda6644302b15502981ae3b8 (exact_match)
  - Mainnet registry 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F, 45-day season (ends 10:19 VN 03/01/2027). Full record: docs/MAINNET_DEPLOY.md.
- **Tests:** Foundry suite, **30/30 passing** (free-mint gating, paid mint and
  pool accounting, merge levels, forge caps and downgrade, battle
  escrow/payout/cancel, season snapshot and claim math, double-claim revert).
- **Open source:** contracts are verified and open-source on BscScan/Sourcify
  after deployment. [TODO: repo link]

Key numbers: 2 free mints per wallet; paid mint 0.005 BNB, max 10 mints per
wallet total; base supply cap 10,000. Merge: burn two Heroes → one Hero at
`max(levelA, levelB) + 1`, max Lv10 (10 base Heroes reach Lv10). Forge: burn
a Lv10 Hero → tiered Hero, rolled Legendary 1% / Mythic 5% / Rare 20% /
Uncommon 74%, with hard caps enforced and downgrade to the next available
tier if the rolled tier is exhausted. Power = `100 + 25 × (level − 1)`,
tier multiplier Uncommon ×1.2 / Rare ×1.5 / Mythic ×2 / Legendary ×3.
Season weights: Uncommon 1 / Rare 5 / Mythic 20 / Legendary 100.

## 4. How to play

1. **Connect a wallet.** Standard injected-wallet connect (MetaMask / Binance
   Wallet extension). No QR login, no Agentic Wallet web login, no seed
   phrase or private key is ever requested.
2. **Mint a free Hero.** Requires an Agent ID in the connected wallet
   (2 free per wallet). Extra Heroes cost 0.005 BNB each, up to 10 total.
3. **Merge and forge.** Merge two Heroes into a higher-level one, up to
   Lv10, then forge a Lv10 Hero into a tiered Hero. Tier caps are shown live
   in the UI.
4. **Battle and claim the season.** Create or accept a PvP battle (bet
   0.001–0.05 BNB per side). The UI shows the honest win probability,
   `powerA / (powerA + powerB)` — the loser keeps their Hero; only the bet
   is at stake. The winner takes 95% of the pot plus 1,000 $FORGE; 5% goes
   to the season pool. After the season ends, tiered Heroes claim their
   weighted share of the pool.

Rewards are not guaranteed: battle outcomes are probabilistic and the season
pool depends on paid mints and battle activity. No profit is promised
anywhere in the game or the UI.

The frontend is a static single-page app (`frontend/index.html`, ethers v6):
Connect wallet, Mint Hero, My Heroes, Merge, Forge (live tier caps), Battle
(open battles, create/accept, displayed odds), Pool & Season (pool size,
season end, snapshot and claim).

## 5. Plan to reach 30+ interacting Agent ID holders

- **Free-mint distribution through existing free-mint channels.** After
  mainnet deployment we will announce the free mint (2 free per wallet, Agent
  ID holders only) on Boltbook and the Telegram free-mint channels where we
  already reach an established community of Agent ID holders who actively
  claim free mints. These are the channels our community already watches
  daily, so the announcement reaches real holders, not paid traffic.
- **Reasons to come back and interact, not just mint once.** PvP battles
  (BNB pot + $FORGE per win) and the end-of-season pool (tier-weighted, so
  merging and forging matter) give holders a reason to return and transact
  repeatedly. Paid mints (0.005 BNB) grow the season pool, aligning later
  players with earlier ones.
- **Milestones after mainnet deploy:** announce on both channels on day 1;
  track interacting Agent ID addresses on-chain (distinct registry holders
  calling mint/merge/forge/battle) and report progress against the 30-holder
  threshold.

## 6. Compliance checklist

- **No Binance brand impersonation.** The project is named AgentForge, uses
  no Binance name, logo, or domain, and does not present itself as Binance.
- **No QR login.** The frontend uses injected-wallet connect only; there is
  no web QR login for the Agentic Wallet.
- **No bypassing transaction confirmation.** Every on-chain action is a
  normal wallet transaction the user reviews and confirms; the app never
  signs or submits anything silently.
- **No unauthorized transfers.** The contract only moves NFTs or BNB that
  the user explicitly escrows by calling a function (battle bet, battle NFT
  escrow); there is no approval harvesting and no hidden transfer.
- **No collection of secrets.** The app never asks for seed phrases, private
  keys, API secrets, or pairing codes, and stores none.
- **No profit promises.** The UI and this brief state that rewards are not
  guaranteed; win probabilities are shown honestly and the season pool
  depends on actual paid mints and battle activity.
- **No Agent ID lookup tool.** Agent ID is used only as an on-chain access
  check for the caller's own wallet; the project does not offer any way to
  look up other people's wallets by Agent ID name.
- **No wash volume or fake accounts.** Activity comes from real Agent ID
  holders via public free-mint channels; we do not create fake accounts or
  manufacture volume.
