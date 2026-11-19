# AgentForge — Contracts

NFT game for Agent ID holders (Binance Agent ID Hackathon, submission deadline
15:00 VN 09/12/2026). Full spec: `../SPEC.md`.

## Toolchain (decision)

**Foundry 1.9.0** (installed via `foundryup`, `~/.foundry/bin`). The machine had
no `forge`/`cast`/`solc` at the start; `foundryup` worked on the first try, so
the Hardhat fallback was not needed. Solidity **0.8.24** (pinned in
`foundry.toml`), OpenZeppelin **v5.7.0** (`lib/openzeppelin-contracts`).
Make sure `~/.foundry/bin` is on your `PATH`:

```shell
export PATH="$PATH:$HOME/.foundry/bin"
```

## Layout

| File | What it is |
|---|---|
| `src/AgentForge.sol` | ERC721 `AgentForge Hero` (AFHERO) + all game logic |
| `src/ForgeToken.sol` | ERC20 `AgentForge` / `FORGE`, fixed supply 1,000,000,000, minted once to the game contract |
| `src/MockAgentIdRegistry.sol` | Testnet-only ERC721, public mint — stand-in for the real Agent ID registry |
| `test/AgentForge.t.sol` | 30 tests (incl. 2 harness contracts with small tier caps) |
| `abi/AgentForge.json`, `abi/ForgeToken.json` | ABIs for the frontend |

## Run

```shell
forge build
forge test            # 30 tests, all passing
forge test -vv        # verbose
```

## Main functions (`AgentForge`)

Constructor: `AgentForge(address registry, uint256 seasonDuration)` — mainnet
registry `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`, season 30 days;
testnet uses `MockAgentIdRegistry`, season 7 days for the demo. The
constructor deploys `ForgeToken`; the full fixed supply lands in the game
contract, which pays battle winners 1,000 FORGE each.

- `mintFree()` — 1 free Lv1 hero, requires an Agent ID, max 2/wallet.
- `mintPaid(uint256 count)` — 0.005 BNB each, wallet total (free + paid) max
  10, base supply max 10,000. 100% of payment goes to `seasonPool`.
- `merge(uint256 a, uint256 b)` — burn 2 tier-NONE heroes → 1 hero at
  `max(levelA, levelB) + 1`, max Lv10 (Lv10 needs 10 base heroes).
- `forge(uint256 tokenId)` — burn a Lv10 tier-NONE hero → tiered Lv10 hero.
  Roll: Legendary 1% / Mythic 5% / Rare 20% / Uncommon 74%; hard caps
  (LG 100, Mythic 500, Rare 5,000) enforced with downgrade to the next
  available tier; Uncommon uncapped.
- `createBattle(uint256 tokenId)` payable — bet 0.001–0.05 BNB, NFT escrowed.
- `acceptBattle(uint256 battleId, uint256 tokenId)` payable — same bet, resolves
  immediately. Win chance = `powerA / (powerA + powerB)`. Winner gets 95% of
  the pot + 1,000 FORGE; 5% goes to the season pool. Both NFTs return to
  their owners — only the bet is at stake.
- `cancelBattle(uint256 battleId)` — creator only, while OPEN; refunds bet + NFT.
- `snapshotSeason()` — once, after `seasonEnd`; freezes pool + total tier weight.
- `claimSeasonReward(uint256 tokenId)` — tiered hero's share:
  `weight / totalWeight * snapshotPool`, one claim per token.
- Views: `levelOf`, `tierOf`, `powerOf`, `heroOf`, `freeMinted`, `mintCountOf`,
  `seasonPool`, `seasonEnd`, `forgeCount(Tier)`, `battleInfo`, `token()`,
  `weightOf`, `tierCap`.

Power: `100 + 25*(level-1)`, tier multiplier NONE ×1, Uncommon ×1.2,
Rare ×1.5, Mythic ×2, Legendary ×3 (integer math truncates halves, e.g. Lv2
Rare = 187). Season weight (for end-of-season pool split, NOT power): Uncommon 1, Rare 5, Mythic 20, Legendary 100;
base heroes weigh 0 (battle rewards only).

## Notes / deviations from SPEC.md

- **No deviation in game rules.** All numbers (caps, prices, bets, shares,
  weights, probabilities) match the spec.
- `tierCap(Tier)` is a `public pure virtual` function returning the spec caps
  in production. It exists so tests can deploy a harness with small caps and
  exercise the forge-downgrade path (otherwise 100+ Legendary forges would be
  needed to hit the cap). Production caps are unchanged.
- `mintFree` / `mintPaid` / `merge` / `forge` / `createBattle` return the new
  token id(s) / battle id for frontend convenience (spec lists the same
  function names; return values are additive only).
- Randomness is prevrandao-based as specified (no Chainlink VRF). Outcomes are
  probabilistic; the frontend must show probabilities, never guarantees.
- The owner has no fund-moving powers: no dev cut, no withdraw function.
  `seasonPool` is an accounting variable, not raw balance.
- `MockAgentIdRegistry` is testnet-only and must never be used on mainnet.

## Deploy

Local tests only in this milestone. **No mainnet deploy** — testnet deploy is a
separate milestone and needs parent approval + BNB top-up first.
