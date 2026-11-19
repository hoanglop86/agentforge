# AgentForge — BSC Testnet Deployment Record

Deployed **19/11/2026 ~06:42 VN** (block 143,537,087). Deployer funded by VO
with 0.1 tBNB from his Elysium wallet (no faucet captcha needed).
Chain 97 (BSC testnet). Season: 7 days, ends **06:42 VN 26/11/2026**
(`seasonEnd` 1795650173).

## Contracts

| Contract | Address | Deploy tx | Block | Gas used |
|---|---|---|---|---|
| MockAgentIdRegistry | `0x4315F61dE24A1e7B0fA0199CF49Be742432D7dcd` | `0xc7183a375045db778028df340b7e685db0dc07fd343b99c199ea5557052582c0` | 143,537,087 | 999,904 |
| AgentForge (game) | `0x69Fd48117Ec4f920501B573096133fefEA2c6096` | `0xfec5b10dc035df504f996160e35339f09165b01caa155726f6a860da810317de` | 143,537,087 | 3,735,649 |
| ForgeToken ($FORGE) | `0x79A82C7a2234e34E1108665Bbc9EBC6Ef1aCe710` | (created by AgentForge constructor) | 143,537,087 | incl. above |

- Deployer: `0x7455764740784BbFa3Fd165c16eFfA0E396Cd5CA`
- Deploy gas total: 4,735,553 @ 1 gwei = **0.004735553 tBNB**
- `token()` → ForgeToken ✓, `registry()` → MockRegistry ✓,
  `seasonPool()` = 0 ✓, FORGE totalSupply 1,000,000,000 (all held by game) ✓

## Verification (Sourcify, chain 97)

- AgentForge: https://sourcify.dev/#/lookup/0x69Fd48117Ec4f920501B573096133fefEA2c6096
  (also: https://testnet.bscscan.com/address/0x69Fd48117Ec4f920501B573096133fefEA2c6096#code)
- MockAgentIdRegistry: https://sourcify.dev/#/lookup/0x4315F61dE24A1e7B0fA0199CF49Be742432D7dcd
- ForgeToken: https://sourcify.dev/#/lookup/0x79A82C7a2234e34E1108665Bbc9EBC6Ef1aCe710

All three return 200 on Sourcify v2 `?fields=abi` (exact/partial match).
Note: the first `forge verify-contract` for AgentForge timed out on the CLI
(job 00028bcb); a re-submit (job 049d60d0) verified it.

## Frontend

`frontend/config.js`: `AGENT_FORGE_ADDRESS` set to the AgentForge address above
(CHAIN_ID stays 97). `node --check` OK. index.html/app.js untouched
(English UI translation preserved).

## Smoke test (deployer = Tester 1, per runbook §4)

- `mintSelf()` on MockRegistry: tx `0x1fa36a27c3fc3403d0c6080cd3449f153ebcc8ac9cdbeb586549266d9ff1abf0`,
  block 143,538,093, status 1, gas 73,219 → registry `balanceOf(deployer)` = 1.
- `mintFree()` on AgentForge: tx `0xe985c98ee527d6f1a8efeddf8a3cf488fe0367588b91cbac5673ce1ca0e3bc5f`,
  block 143,538,103, status 1, gas 171,358 → hero #1: level 1, tier 0,
  power 100; `freeMinted(deployer)` = 1; `ownerOf(1)` = deployer. ✓

## Spend so far

- Deploy: 0.004735553 tBNB; smoke test: 0.000244577 tBNB
- **Total: 0.00498013 tBNB. Deployer remaining: 0.09501987 tBNB.**

## Gotchas (for the next deploy)

- BSC testnet `eth_feeHistory` returns baseFee 0, so forge estimates
  maxFeePerGas = 1 wei. First broadcast (publicnode RPC) sent both deploys
  at ~1 wei; they sat unmined and were dropped from the mempool, and forge
  waited for receipts forever. Fix: always pass explicit fees —
  `forge script ... --with-gas-price 1000000000 --priority-gas-price 1000000000`
  (1 gwei). Same trap applies to `cast send`: `--gas-price` alone leaves the
  tip cap at 1 wei ("gas tip cap 1, minimum needed 100000000"); always add
  `--priority-gas-price 1000000000`.
- `bsc-testnet.publicnode.com` worked for reads but the first broadcast hung
  on receipt polling; `https://bsc-testnet-dataseed.bnbchain.org` worked for
  the successful broadcast. `data-seed-prebsc-1-s1` still times out from this VM.
- Stale `broadcast/Deploy.s.sol/97/run-latest.json` from the failed attempt
  blocks re-runs — use `--start-fresh` (archives the old file).

## Still to do (NOT done in this run)

- ~~Full E2E per runbook §4–§5~~ — **DONE 19/11 ~07:10 VN, all checks pass.**
  Record: [TESTNET_E2E.md](TESTNET_E2E.md). Note: GAME1's season pool (0.0401
  tBNB) is still locked until the 7-day season ends 06:42 VN 26/11 — the
  deployer holds the only tier NFT there and can snapshot + claim the full
  0.0401 then.
- Browser test of the actual UI (subagent has no browser).
- Mainnet deploy: NOT done, needs VO approval + BNB top-up (separate step).
