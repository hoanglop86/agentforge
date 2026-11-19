# AgentForge — BSC Testnet Full E2E Test Record

Ran **19/11/2026 ~06:57–07:10 VN** on BSC testnet (chain 97), after VO topped
up the deployer with +0.05 tBNB (balance 0.14501987 tBNB at start).
Wallets: deployer/tester 1 `0x7455764740784BbFa3Fd165c16eFfA0E396Cd5CA`,
tester 2 `0xcF390d3a84bEa917c917795F2d59Fcc53C6dDD60` (funded 0.01 tBNB from
deployer, tx `0x02f035f7bc223a1e771d01735563b164b2ac2bf5e1a3d514996f92b33bcfe6c5`,
block 143,538,782 — runbook said 0.05, but tester 2 only needs ~0.0016 tBNB;
0.01 gives 6x margin and keeps the deployer inside budget).
All txs at 1 gwei. Raw logs: `docs/e2e-inst1.log`, `docs/e2e-inst2.log`.

## Instance 1 — 7-day season (deployed 19/11 06:42 VN)

Game `0x69Fd48117Ec4f920501B573096133fefEA2c6096`,
registry `0x4315F61dE24A1e7B0fA0199CF49Be742432D7dcd`,
ForgeToken `0x79A82C7a2234e34E1108665Bbc9EBC6Ef1aCe710`.
Season ends 06:42 VN 26/11/2026. (Smoke test before E2E: `mintSelf()` +
`mintFree()` → hero #1, level 1, tier 0, power 100 — see TESTNET_DEPLOY.md.)

| Step | Tx | Block | Gas | Result |
|---|---|---|---|---|
| mintFree #2 (wallet 1) | `0xa6c8ba84b0291434b9a54a448f57b323349374e596e39af3977271edbd82cd9d` | 143,538,820 | 102,958 | hero #2, Lv1/T0; `freeMinted(A1)` = 2 ✓ |
| 3rd mintFree (simulated) | — | — | — | reverts `FreeMintExhausted` (0x45f741f8) ✓ |
| mintPaid(8), 0.04 tBNB | `0xf21774a8e484dd88f611caa776b49722ad49795b8a4ae973cde72e9f0a2a0cb5` | 143,538,840 | 476,019 | tokens 3–10; `mintCountOf(A1)` = 10; `seasonPool` = 0.04 ✓ |
| merge 1+2 → 11 | `0x2b9b44b150147e4221df500a706af76bc8548b8ffdca457fa6e97288da75d42e` | 143,538,855 | 99,246 | Lv2 ✓ |
| merge 11+3 → 12 | `0x6c955184f8c3b33796785aef9b2e0af68bca77aebcb0dbda0417a89ee3cae4a7` | 143,538,863 | 99,236 | Lv3 ✓ |
| merge 12+4 → 13 | `0xc066ae8f64028772c07d6653f7474afc4d7a5af2f66585bcb5ff179336490776` | 143,538,872 | 99,236 | Lv4 ✓ |
| merge 13+5 → 14 | `0xbfcf5f093effb5b77e4e4d5ed043c9261a4bae899ab9e086708cbe1290eb1451` | 143,538,879 | 99,236 | Lv5 ✓ |
| merge 14+6 → 15 | `0xa2f9078860a98d7a06b2300e31982eaa39d45ae090cb830081a4d4f181c5e6d4` | 143,538,888 | 99,236 | Lv6 ✓ |
| merge 15+7 → 16 | `0x01d458de81df2932cb6c8a5df2bb461fbacdb810a91c122fb10ce1cf21d8e723` | 143,538,897 | 99,236 | Lv7 ✓ |
| merge 16+8 → 17 | `0x919da7121ff9de66653fce5ff8998f96e29684e84956e97972eaf6711fb126cf` | 143,538,912 | 99,236 | Lv8 ✓ |
| merge 17+9 → 18 | `0x4d88bdb6d2d0cef453acc98cabd25b6006b1b03eb098264601167f6fc4bc7e1a` | 143,538,921 | 99,236 | Lv9 ✓ |
| merge 18+10 → 19 | `0x7884bd7503b4601318f2d985978d47ab692f8d3e03a274463bb41cb111fc7ff9` | 143,538,929 | 99,236 | Lv10, tier 0, power 325 ✓ |
| forge(19) → 20 | `0x278122023878caed4c10d813d3b192fa8b86b173a0cd45b68c4ccfea356780bd` | 143,538,940 | 154,826 | Lv10, **tier 1 Uncommon**, power 390 (= 325 × 1.2); `weightOf(1)` = 1; `forgeCount(1)` = 1 ✓ |
| tester2 mintSelf | `0x61d34779334462de74da148513e6f3709ff59f1de1144fd88ed1ed92ebd5fb22` | 143,538,962 | 73,219 | registry balance 1 ✓ |
| tester2 mintFree → 21 | `0x114e02ece6c1d90020094b3857af15a9f971d9f7ab76b94d531058bda59eca88` | 143,538,970 | 154,258 | Lv1/T0 ✓ |
| tester2 mintFree → 22 | `0x90ae353884c3dc9360cf264a8ca2851f9af2679ad13e65ab70c0374b6b876766` | 143,538,984 | 102,958 | Lv1/T0 ✓ |
| createBattle(20), bet 0.001 | `0x0f8a77bc3e38329911dda17952abcf35c7ae29f50b59517138049f18a8ed7833` | 143,538,994 | 157,824 | battle 1 OPEN ✓ |
| acceptBattle(1, 21), bet 0.001 | `0x1ac0fdb84d364f0205fdfd5a2f66eea2b6ebce644443e6ee6b850a3e5a3634ab` | 143,539,004 | 204,195 | RESOLVED, **winner = tester 2 (A2)** ✓ |

**Battle 1 outcome (the underdog won):** creator Lv10 Uncommon power 390 vs
challenger Lv1 power 100 — challenger win chance 100/490 ≈ 20.4%, and the
`prevrandao` roll landed there. Winner A2 received 0.0019 tBNB (95% of the
0.002 pot) + 1,000 FORGE (`balanceOf(A2)` = 1,000 FORGE; A1 = 0);
`seasonPool` = 0.0401 (0.04 mints + 0.0001 = 5% of pot) ✓. Both NFTs
returned: `ownerOf(20)` = A1, `ownerOf(21)` = A2 ✓. Mechanics verified —
the 20% outcome is legitimate randomness, not a bug.

Wallet 1 spent: 0.04 (paid mints) + 0.001 (bet) + 0.001784761 gas =
0.042784761 tBNB → balance 0.092214109. Tester 2 net: −0.00153463
(gas + bet) + 0.0019 (winnings) = +0.00036537 → balance 0.01036537.

## Instance 2 — 600s season (deployed 19/11 ~07:00 VN)

Game `0xfd51891a7df468f0e6c3dd49a09257e49b3e4832`,
registry `0x3adab0edc1a36b0cf476aaf8c6ee0f401dc60892` (fresh — the deploy script
always deploys a new registry, so both wallets did `mintSelf()` on REG2;
runbook §5's "registry is shared" is wrong, adapted on the fly),
ForgeToken `0x24A05dc05a51352C16598a8d100d08267e37Bdb9` (each game deploys its
own token). `seasonEnd` = 1795046901 (~07:01:41 VN 19/11).

| Step | Tx | Block | Gas | Result |
|---|---|---|---|---|
| Deploy REG2 | `0x5156149ab16b84bf665ca262e8362c235dfc83f80eb266717ed55bce33252475` | 143,539,144 | 999,904 | `0x3adab0edc1a36b0cf476aaf8c6ee0f401dc60892` ✓ |
| Deploy GAME2 | `0x78628798f4088ae5966dea62f8620006c5372af4b827f067f8d423a424212e31` | 143,539,145 | 3,735,637 | `token()` → new ForgeToken, `registry()` → REG2 ✓ |
| mintSelf wallet 1 (REG2) | `0xfa73456a3650badd97772041cd87494864a06a2ecb71535d66f2b7bd2fb686d9` | 143,539,238 | 73,219 | balance 1 ✓ |
| mintSelf wallet 2 (REG2) | `0xa6eaf81e1d8894a27a50f6b055e603db29724f499779cc1643033672d7fa02ec` | 143,539,248 | 73,219 | balance 1 ✓ |
| mintFree → 1 (wallet 1) | `0x300ad0af66c06ba7096c5a2c33ecebe155aae6033f2ef97323622e58cd1da7ea` | 143,539,263 | 171,358 | Lv1/T0 ✓ |
| mintFree → 2 (wallet 1) | `0x77dfa60066fdcc1422b8d0855050e68d6b72ec11c06080110687f4e9a131f47b` | 143,539,272 | 102,958 | Lv1/T0 ✓ |
| mintPaid(8), 0.04 tBNB | `0x5d45a6b4f731fc292920925f0277286db4b631f56e9aef86da653d90b6cba22b` | 143,539,279 | 476,019 | tokens 3–10; `mintCountOf(A1)` = 10; `seasonPool` = 0.04 ✓ |
| merge 1+2 → 11 | `0x1c2d7c0687a279ff328aa0965a1d47aaf7102d20fc8dc2d362a1187e4d2f9a7a` | 143,539,295 | 99,246 | Lv2 ✓ |
| merge 11+3 → 12 | `0x5c36dd8c2a324f61f91c61b663ad6f606fda342141be5e7c2caeed1de8db79f5` | 143,539,304 | 99,236 | Lv3 ✓ |
| merge 12+4 → 13 | `0xd81e0710e7efc50a9b84d6f1146fc0b4af43dfd5087bd78bef80381e9d2f3310` | 143,539,311 | 99,236 | Lv4 ✓ |
| merge 13+5 → 14 | `0x0e837ae6de8a640e64b3f674bf62c9bdf60700324c31fb6578e7dd75a59a8ebe` | 143,539,320 | 99,236 | Lv5 ✓ |
| merge 14+6 → 15 | `0xa72ea0614ae5411ff9390d90bec0c10f19baf8bad9fc50e714a26e6967815585` | 143,539,329 | 99,236 | Lv6 ✓ |
| merge 15+7 → 16 | `0x99e7574a99503beb6dc81deda2ead9344034af0ed4d6dbe53af38024ee1d3fe2` | 143,539,344 | 99,236 | Lv7 ✓ |
| merge 16+8 → 17 | `0x2209b3f833e5307129d8756b163307411443a3b94af3c9abfa5781e707954e71` | 143,539,351 | 99,236 | Lv8 ✓ |
| merge 17+9 → 18 | `0x45bf5e915fb4dec7302c8ae46c6d6b7ce78053e1d8e629b09eaf5f3389a7ffca` | 143,539,360 | 99,236 | Lv9 ✓ |
| merge 18+10 → 19 | `0xadc657452c01405b56966eff0a00ce96d45b47286164021fc24a47506cd10978` | 143,539,370 | 99,236 | Lv10, tier 0, **power 325** ✓ |
| forge(19) → 20 | `0xfe8c9e6b3d58ebbddd7ec5e80bada5e4085dfe3aec89e6675bc1591dc843c8e8` | 143,539,383 | 155,301 | Lv10, **tier 2 Rare**, power 487 (= 325 × 1.5); `weightOf(2)` = 5; `totalTierWeight` = 5 ✓ |
| tester2 mintFree → 21 | `0xfde0bba84fc5b56c1a978f96fc7e1110d98270abaa0570b1c9eeb6f820cdbb50` | 143,539,406 | 154,258 | Lv1/T0 ✓ |
| tester2 mintFree → 22 | `0x7bde721dcfbbeede00c2fa82a4850603b64312d96378f0f2a23a3a809fb2cebc` | 143,539,416 | 102,958 | Lv1/T0 ✓ |
| createBattle(20), bet 0.001 | `0xa31844d87a96626c168a98df2e02d63184f0c955b3fc4306a2588da9e7d0daf8` | 143,539,424 | 157,824 | battle 1 OPEN ✓ |
| acceptBattle(1, 21), bet 0.001 | `0xd8b3284f417f726ef0fd2bf0c2a056c3343bed1c78235e68ec570cc33c669bfc` | 143,539,432 | 206,724 | RESOLVED, **winner = wallet 1 (A1)** ✓ |

**Battle 2 outcome:** creator Lv10 Rare power 487 vs challenger Lv1 power 100 —
creator win chance 487/587 ≈ 83%, and won. `seasonPool` = 0.0401 ✓
(0.04 + 0.0001 fee). Winner A1 gets 0.0019 tBNB + 1,000 FORGE (GAME2 token).

### Snapshot + claim — DONE ✓

| Step | Tx | Block | Gas | Result |
|---|---|---|---|---|
| snapshotSeason() | `0xff8759aaf98b19a71e81751a1f976fe930cfe6b511cf62399960043e3c27deab` | 143,540,516 | 95,568 | `snapshotPool` = 0.0401, `snapshotTotalWeight` = 5 ✓ |
| claimSeasonReward(20) | `0x9531825ede460c591fc1a7f749f2defaf5983b26d9c4614855a19713dcaee0ba` | 143,540,532 | 66,729 | **+0.0401 tBNB to A1** (sole tier NFT, weight 5/5 — full pool); A1 0.046253187 → 0.086286458; `seasonPool` = 0; `seasonClaimed(20)` = true ✓ |
| 2nd claimSeasonReward (simulated) | — | — | — | reverts `AlreadyClaimed` (0x646cf558) ✓ |
| snapshotSeason again (simulated) | — | — | — | reverts `SeasonAlreadySnapshotted` (0x94de7f0d) ✓ |

## Final balances & spend

- Deployer (A1): **0.086286458 tBNB** (started 0.14501987). Tester 2 (A2): **0.008828211 tBNB**.
- **Net E2E spend: 0.049905201 tBNB** — gas 0.009805201 (incl. instance-2 deploy 0.004735541) + 0.0401 locked in GAME1's season pool. That 0.0401 is NOT lost: A1 holds GAME1's only tier NFT (token 20, Uncommon, weight 1/1), so after GAME1's season ends 06:42 VN 26/11 it can snapshot + claim the full 0.0401 back.
- Battle rewards: A2 won battle 1 → +0.0019 tBNB + 1,000 FORGE (GAME1 token); A1 won battle 2 → +0.0019 tBNB + 1,000 FORGE (GAME2 token `0x24A05dc05a51352C16598a8d100d08267e37Bdb9`).

## Issues hit during the run (all handled)

1. **`e2e-inst2.sh` arithmetic bug:** `cast call` prints `1795046901 [1.795e9]`, so the script's `SEASON_END` variable contained the suffix and the wait math failed with a syntax error — the script died AFTER the battle, BEFORE snapshot/claim. Recovered by re-reading `seasonEnd` with `awk '{print $1}'` and running the snapshot/claim steps manually. Nothing was lost; no tx was duplicated.
2. **Runbook §5 wrong about the registry:** it says instance 2 reuses the shared registry, but `Deploy.s.sol` always deploys a FRESH `MockAgentIdRegistry`. Both wallets did `mintSelf()` on REG2 (`0x3adab0edc1a36b0cf476aaf8c6ee0f401dc60892`) before minting on GAME2.
3. **Tester-2 funding:** runbook says 0.05 tBNB; funded 0.01 instead (tester 2 needed ~0.0016; 0.01 = 6x margin) to stay inside the 0.13 tBNB budget cap.
4. **Minor:** `heroOf()` on a burned token (e.g. token 19 after forge) reverts with an arithmetic panic (0x11) instead of returning zeros — cosmetic, only affects reads of deleted heroes; the frontend never queries burned ids.
5. **Battle randomness is real:** battle 1's 20.4% underdog (Lv1 power 100 vs Lv10 Uncommon power 390) won. Both battles resolved correctly with the right payouts.

## Verdict

**All E2E checks pass.** Free mints (cap enforced), paid mints (pool accounting),
merge chain to Lv10 (power 325), forge (Uncommon weight 1, Rare weight 5 —
matches SPEC 1/5/20/100), PvP battles (escrow, 95/5 split, 1,000 FORGE
bonus, NFTs returned), season snapshot + weighted claim + double-claim and
double-snapshot guards. No contract changes needed. Remaining work: browser
test of the actual UI (subagent has no browser) and mainnet deploy (needs VO
approval + BNB top-up, separate step).
