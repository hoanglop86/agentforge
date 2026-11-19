// AgentForge frontend — static page, ethers v6 via CDN, injected wallet only.
// No QR login, no WalletConnect, no secrets. All contract calls use the exact
// function names from contracts/abi/AgentForge.json (108 entries) and
// contracts/abi/ForgeToken.json (19 entries).
//
// NOTE: the game contract has NO ERC721Enumerable (no tokenOfOwnerByIndex in
// the ABI), so "My Heroes" is built from Transfer events (received minus
// sent, verified with ownerOf). A bounded ownerOf scan is the fallback.

"use strict";

// ---------------------------------------------------------------------------
// Constants (from SPEC.md + AgentForge.sol — verified against the ABI)
// ---------------------------------------------------------------------------
const TIER_NAMES = ["NONE", "Uncommon", "Rare", "Mythic", "Legendary"];
const TIER = { NONE: 0, UNCOMMON: 1, RARE: 2, MYTHIC: 3, LEGENDARY: 4 };
const BATTLE_STATUS = ["OPEN", "RESOLVED", "CANCELLED"];
const FREE_MINTS_PER_WALLET = 2n;
const MAX_MINTS_PER_WALLET = 10n;
const PAID_MINT_PRICE_ETHER = "0.005"; // also read live via PAID_MINT_PRICE()
const MIN_BET_ETHER = "0.001";
const MAX_BET_ETHER = "0.05";

// Minimal ERC721 interface for the Agent ID registry check (balanceOf only).
const REGISTRY_ABI = ["function balanceOf(address owner) view returns (uint256)"];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
let provider = null;
let signer = null;
let account = null;
let game = null; // AgentForge contract
let gameAbi = null;
let forgeToken = null; // ForgeToken contract (address read from game.token())
let registry = null; // Agent ID registry (address read from game.registry())
let heroes = []; // [{ tokenId, level, tier, power, inBattle }]
let openBattles = []; // [{ battleId, creator, creatorTokenId, bet, creatorPower }]
let selectedBattleId = null;
let season = null; // { pool, end, snapshotDone, snapshotPool, snapshotTotalWeight, totalWeight }
let forgeCaps = null; // { counts: {1..4}, caps: {1..4} }
let countdownTimer = null;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const $ = (id) => document.getElementById(id);

function log(msg) {
  const el = $("log");
  const line = `[${new Date().toLocaleTimeString()}] ${msg}`;
  el.textContent = el.textContent === "—" ? line : el.textContent + "\n" + line;
}

function setTx(msg, isErr) {
  const el = $("txStatus");
  el.textContent = msg || "";
  el.className = isErr ? "bad" : "ok";
}

function shortAddr(a) {
  return a ? a.slice(0, 6) + "…" + a.slice(-4) : "–";
}

function fmtBnb(wei) {
  try { return ethers.formatEther(wei) + " BNB"; } catch { return String(wei); }
}

function errMsg(e) {
  // ethers v6 surfaces reverts as e.reason / e.info.error.message / e.message.
  if (e && e.reason) return e.reason;
  if (e && e.info && e.info.error && e.info.error.message) return e.info.error.message;
  if (e && e.shortMessage) return e.shortMessage;
  return (e && e.message) || String(e);
}

function isDeployed() {
  return (
    CONFIG.AGENT_FORGE_ADDRESS &&
    CONFIG.AGENT_FORGE_ADDRESS.toLowerCase() !== ethers.ZeroAddress.toLowerCase()
  );
}

function requireReady() {
  if (!isDeployed()) { setTx("No contract address yet — paste AGENT_FORGE_ADDRESS into config.js after deploying.", true); return false; }
  if (!game || !account) { setTx("Please connect your wallet first.", true); return false; }
  return true;
}

// Run a write tx: wait for 1 confirmation, refresh, report hash.
async function sendTx(promiseFn, label) {
  setTx(`${label}… waiting for your confirmation in the wallet…`);
  try {
    const tx = await promiseFn();
    setTx(`${label}… sent (tx ${tx.hash}). Waiting for confirmation…`);
    log(`${label}: tx ${tx.hash}`);
    const receipt = await tx.wait(1);
    if (receipt.status !== 1n && receipt.status !== 1) throw new Error("Transaction failed on-chain (status 0).");
    setTx(`${label} succeeded. Tx: ${tx.hash}`);
    log(`${label} succeeded: ${tx.hash}`);
    await refreshAll();
    return receipt;
  } catch (e) {
    setTx(`${label} failed: ${errMsg(e)}`, true);
    log(`${label} failed: ${errMsg(e)}`);
    throw e;
  }
}

// ---------------------------------------------------------------------------
// Wallet connect (injected provider only)
// ---------------------------------------------------------------------------
async function connectWallet() {
  if (typeof window.ethereum === "undefined") {
    setTx("No wallet found in the browser. Install MetaMask or a wallet extension, then reload the page.", true);
    return;
  }
  try {
    provider = new ethers.BrowserProvider(window.ethereum);
    const accounts = await provider.send("eth_requestAccounts", []);
    account = accounts[0];
    signer = await provider.getSigner();
    $("walletStatus").textContent = `Connected: ${shortAddr(account)}`;
    log(`Wallet connected: ${account}`);

    // Wrong network? Ask the wallet to switch to CONFIG.CHAIN_ID.
    const net = await provider.getNetwork();
    if (Number(net.chainId) !== CONFIG.CHAIN_ID) {
      await switchChain(CONFIG.CHAIN_ID);
    }
    await initContracts();
    await refreshAll();

    window.ethereum.on("accountsChanged", (accs) => {
      account = accs[0] || null;
      if (!account) { $("walletStatus").textContent = "Wallet disconnected."; return; }
      initContracts().then(refreshAll);
    });
    window.ethereum.on("chainChanged", () => window.location.reload());
  } catch (e) {
    setTx(`Wallet connection failed: ${errMsg(e)}`, true);
  }
}

async function switchChain(chainId) {
  const hex = "0x" + chainId.toString(16);
  try {
    await window.ethereum.request({ method: "wallet_switchEthereumChain", params: [{ chainId: hex }] });
  } catch (e) {
    if (e && e.code === 4902 && CONFIG.CHAINS[chainId]) {
      await window.ethereum.request({ method: "wallet_addEthereumChain", params: [CONFIG.CHAINS[chainId]] });
    } else {
      throw e;
    }
  }
}

async function initContracts() {
  if (!isDeployed()) {
    $("deployBanner").hidden = false;
    return;
  }
  $("deployBanner").hidden = true;
  if (!gameAbi) {
    const [forgeAbi, tokenAbi] = await Promise.all([
      fetch("abi/AgentForge.json").then((r) => { if (!r.ok) throw new Error("Could not load abi/AgentForge.json"); return r.json(); }),
      fetch("abi/ForgeToken.json").then((r) => { if (!r.ok) throw new Error("Could not load abi/ForgeToken.json"); return r.json(); }),
    ]);
    gameAbi = forgeAbi;
    window.__FORGE_TOKEN_ABI = tokenAbi; // kept for the token contract below
  }
  game = new ethers.Contract(CONFIG.AGENT_FORGE_ADDRESS, gameAbi, signer);
  // Registry + token addresses are read on-chain from the game contract.
  const [registryAddr, tokenAddr] = await Promise.all([game.registry(), game.token()]);
  registry = new ethers.Contract(registryAddr, REGISTRY_ABI, provider);
  forgeToken = new ethers.Contract(tokenAddr, window.__FORGE_TOKEN_ABI, provider);
  log(`Game: ${CONFIG.AGENT_FORGE_ADDRESS} | Registry: ${registryAddr} | $FORGE: ${tokenAddr}`);
}

// ---------------------------------------------------------------------------
// Reads
// ---------------------------------------------------------------------------
async function loadHeroes() {
  // Primary: Transfer events (received − sent), verified with ownerOf.
  // The ABI has no tokenOfOwnerByIndex, so events are the enumeration path.
  const received = await game.queryFilter(game.filters.Transfer(null, account));
  const sent = await game.queryFilter(game.filters.Transfer(account, null));
  const sentIds = new Set(sent.map((e) => e.args.tokenId.toString()));
  const ownedIds = [...new Set(received.map((e) => e.args.tokenId.toString()))]
    .filter((id) => !sentIds.has(id));
  const list = [];
  for (const id of ownedIds) {
    try {
      const owner = await game.ownerOf(id);
      if (owner.toLowerCase() !== account.toLowerCase()) continue; // escrowed / moved
      const [level, tier, power] = await game.heroOf(id);
      const inBattle = await game.inBattle(id);
      list.push({ tokenId: BigInt(id), level: Number(level), tier: Number(tier), power, inBattle });
    } catch { /* token burned after the event window — skip */ }
  }
  // Fallback if events returned nothing but balanceOf says otherwise
  // (e.g. RPC event limits): bounded ownerOf scan up to baseMinted +
  // forged count + merges seen in events + margin.
  const bal = await game.balanceOf(account);
  if (list.length < Number(bal)) {
    log(`Event enumeration found ${list.length}/${bal} heroes — falling back to ownerOf scan.`);
    const baseMinted = await game.baseMinted();
    const forgeTotal = [1, 2, 3, 4].reduce((s, t) => s + Number(forgeCaps?.counts?.[t] ?? 0), 0);
    const mergeEvents = await game.queryFilter(game.filters.Merge(account, null, null));
    const upper = Number(baseMinted) + forgeTotal + mergeEvents.length + 5;
    const known = new Set(list.map((h) => h.tokenId.toString()));
    for (let id = 1; id <= upper && list.length < Number(bal); id++) {
      if (known.has(String(id))) continue;
      try {
        const owner = await game.ownerOf(id);
        if (owner.toLowerCase() !== account.toLowerCase()) continue;
        const [level, tier, power] = await game.heroOf(id);
        const inBattle = await game.inBattle(id);
        list.push({ tokenId: BigInt(id), level: Number(level), tier: Number(tier), power, inBattle });
      } catch { /* nonexistent / burned token */ }
    }
  }
  list.sort((a, b) => (a.tokenId < b.tokenId ? -1 : 1));
  heroes = list;
}

async function loadBattles() {
  const nextId = await game.nextBattleId();
  const list = [];
  for (let id = 1n; id < nextId; id++) {
    try {
      const b = await game.battleInfo(id);
      if (Number(b.status) !== 0) continue; // only OPEN
      const creatorPower = await game.powerOf(b.creatorTokenId);
      list.push({
        battleId: id,
        creator: b.creator,
        creatorTokenId: b.creatorTokenId,
        bet: b.bet,
        creatorPower,
      });
    } catch { /* battle slot unreadable — skip */ }
  }
  openBattles = list;
}

async function loadSeason() {
  const [pool, end, done, snapPool, snapWeight, totalWeight] = await Promise.all([
    game.seasonPool(),
    game.seasonEnd(),
    game.snapshotDone(),
    game.snapshotPool(),
    game.snapshotTotalWeight(),
    game.totalTierWeight(),
  ]);
  season = { pool, end, snapshotDone: done, snapshotPool: snapPool, snapshotTotalWeight: snapWeight, totalWeight };
}

async function loadForgeCaps() {
  const counts = {};
  const caps = {};
  for (const t of [TIER.UNCOMMON, TIER.RARE, TIER.MYTHIC, TIER.LEGENDARY]) {
    counts[t] = await game.forgeCount(t);
    caps[t] = await game.tierCap(t);
  }
  forgeCaps = { counts, caps };
}

function countdownText(endUnix) {
  const diff = Number(endUnix) - Math.floor(Date.now() / 1000);
  if (diff <= 0) return "Ended";
  const d = Math.floor(diff / 86400);
  const h = Math.floor((diff % 86400) / 3600);
  const m = Math.floor((diff % 3600) / 60);
  const s = diff % 60;
  return `${d}d ${h}h ${m}m ${s}s`;
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------
function renderWalletInfo(agentIdBal, freeMinted, mintCount, baseMinted, forgeBal) {
  const freeLeft = FREE_MINTS_PER_WALLET - freeMinted;
  $("walletInfo").innerHTML =
    `<p>Wallet address: <code>${account}</code></p>` +
    `<p>Agent ID: <b class="${agentIdBal > 0n ? "ok" : "bad"}">${agentIdBal > 0n ? `Has (${agentIdBal} ID)` : "NONE — you need to hold an Agent ID to mint"}</b></p>` +
    `<p>Free mints left: <b>${freeLeft > 0n ? freeLeft : 0n} / 2</b> · Total minted: <b>${mintCount} / 10</b> · Total Heroes minted: <b>${baseMinted} / 10,000</b></p>` +
    `<p>Your $FORGE balance: <b>${ethers.formatEther(forgeBal)} FORGE</b></p>`;
  $("mintStatus").innerHTML =
    `Free mints left: <b>${freeLeft > 0n ? freeLeft : 0n} / 2</b> · Minted: <b>${mintCount} / 10</b> · ` +
    `Remaining supply: <b>${10000n - baseMinted}</b> Heroes.`;
  $("btnMintFree").disabled = freeLeft <= 0n || agentIdBal === 0n;
  const paidLeft = MAX_MINTS_PER_WALLET - mintCount;
  const paidInput = $("paidCount");
  paidInput.max = String(paidLeft > 8n ? 8 : paidLeft);
  if (Number(paidInput.value) > Number(paidInput.max)) paidInput.value = paidInput.max;
  $("btnMintPaid").disabled = paidLeft <= 0n || agentIdBal === 0n;
  updatePaidTotal();
}

function renderHeroes() {
  const box = $("heroList");
  if (heroes.length === 0) {
    box.innerHTML = `<p class="muted">You don’t have any Heroes yet. Mint a free one in section 2 (you need to hold an Agent ID).</p>`;
  } else {
    box.innerHTML = heroes.map((h) =>
      `<div class="card"><b>Hero #${h.tokenId}</b> · Lv <b>${h.level}</b> · Tier <b>${TIER_NAMES[h.tier]}</b> · Power <b>${h.power}</b>` +
      (h.inBattle ? ` · <span class="bad">in a battle (escrowed)</span>` : "") +
      `</div>`
    ).join("");
  }
  const forgeBalEl = $("forgeBalance");
  // Filled in refreshAll via forgeToken balance; keep text if already set.
  if (!forgeBalEl.dataset.set) forgeBalEl.textContent = "";

  // Fill the selects from the same hero list.
  fillSelect($("mergeA"), heroes.filter((h) => h.tier === TIER.NONE && h.level < 10 && !h.inBattle), "Hero");
  fillSelect($("mergeB"), heroes.filter((h) => h.tier === TIER.NONE && h.level < 10 && !h.inBattle), "Hero");
  fillSelect($("forgeSelect"), heroes.filter((h) => h.tier === TIER.NONE && h.level === 10 && !h.inBattle), "Hero Lv10");
  fillSelect($("battleHero"), heroes.filter((h) => !h.inBattle), "Hero");
  fillSelect($("acceptHero"), heroes.filter((h) => !h.inBattle), "Hero");
  updateMergePreview();
  updateAcceptOdds();
}

function fillSelect(sel, list, label) {
  const prev = sel.value;
  sel.innerHTML = `<option value="">— select ${label} —</option>` +
    list.map((h) => `<option value="${h.tokenId}">#${h.tokenId} · Lv${h.level} · ${TIER_NAMES[h.tier]} · Power ${h.power}</option>`).join("");
  if (prev && [...sel.options].some((o) => o.value === prev)) sel.value = prev;
}

function renderForgeCaps() {
  if (!forgeCaps) return;
  $("capLG").textContent = `${forgeCaps.counts[TIER.LEGENDARY]} / ${forgeCaps.caps[TIER.LEGENDARY]}`;
  $("capMY").textContent = `${forgeCaps.counts[TIER.MYTHIC]} / ${forgeCaps.caps[TIER.MYTHIC]}`;
  $("capRA").textContent = `${forgeCaps.counts[TIER.RARE]} / ${forgeCaps.caps[TIER.RARE]}`;
  $("capUN").textContent = `${forgeCaps.counts[TIER.UNCOMMON]} / ∞`;
}

function renderBattles() {
  const box = $("battleList");
  if (openBattles.length === 0) {
    box.innerHTML = `<p class="muted">No battles are open.</p>`;
  } else {
    box.innerHTML = openBattles.map((b) => {
      const mine = b.creator.toLowerCase() === account.toLowerCase();
      return `<div class="card"><b>Battle #${b.battleId}</b> · Creator: <code>${shortAddr(b.creator)}</code>${mine ? " (yours)" : ""}` +
        ` · Creator Hero: <b>#${b.creatorTokenId}</b> (Power <b>${b.creatorPower}</b>)` +
        ` · Bet: <b>${fmtBnb(b.bet)}</b>` +
        ` <button data-battle="${b.battleId}" class="btn-pick-battle">${mine ? "Created — view" : "Pick this battle"}</button>` +
        (mine ? ` <button data-cancel="${b.battleId}" class="btn-cancel-battle">Cancel battle (refund bet + Hero)</button>` : "") +
        `</div>`;
    }).join("");
  }
  box.querySelectorAll(".btn-pick-battle").forEach((btn) => {
    btn.addEventListener("click", () => {
      selectedBattleId = BigInt(btn.dataset.battle);
      updateAcceptOdds();
      setTx(`Battle #${selectedBattleId} selected. Choose your Hero to see your win chance before battling.`);
    });
  });
  box.querySelectorAll(".btn-cancel-battle").forEach((btn) => {
    btn.addEventListener("click", () => cancelBattle(BigInt(btn.dataset.cancel)));
  });
}

function renderSeason() {
  if (!season) return;
  const ended = Date.now() / 1000 >= Number(season.end);
  const weights = [1, 2, 3, 4].map((t) => {
    const w = { 1: 1, 2: 5, 3: 20, 4: 100 }[t];
    return `${TIER_NAMES[t]}: weight ${w}`;
  }).join(" · ");
  $("seasonInfo").innerHTML =
    `<p>Current season pool: <b>${fmtBnb(season.pool)}</b></p>` +
    `<p>Season ends: <b>${new Date(Number(season.end) * 1000).toLocaleString()}</b> · Time left: <b id="countdown">${countdownText(season.end)}</b></p>` +
    `<p>Current total tier weight: <b>${season.totalWeight}</b> (${weights})</p>` +
    `<p>Snapshot status: <b>${season.snapshotDone ? `Snapshotted — snapshot pool ${fmtBnb(season.snapshotPool)}, total weight ${season.snapshotTotalWeight}` : (ended ? "Season ended — not snapshotted yet, anyone can click the snapshot button." : "Not time to snapshot yet.")}</b></p>`;
  $("btnSnapshot").disabled = !ended || season.snapshotDone;
  if (countdownTimer) clearInterval(countdownTimer);
  countdownTimer = setInterval(() => {
    const el = $("countdown");
    if (el) el.textContent = countdownText(season.end);
  }, 1000);

  // Claim list: only tier NFTs, only after snapshot, only unclaimed.
  const box = $("claimList");
  const claimable = heroes.filter((h) => h.tier !== TIER.NONE);
  if (!season.snapshotDone) {
    box.innerHTML = `<p class="muted">Season not snapshotted yet — claiming opens after the season ends and someone snapshots it.</p>`;
  } else if (claimable.length === 0) {
    box.innerHTML = `<p class="muted">You have no tier Heroes — only forged tier Heroes share the season pool.</p>`;
  } else {
    box.innerHTML = claimable.map((h) => {
      const w = { 1: 1, 2: 5, 3: 20, 4: 100 }[h.tier];
      const est = season.snapshotTotalWeight > 0n
        ? (season.snapshotPool * BigInt(w)) / season.snapshotTotalWeight
        : 0n;
      return `<div class="card"><b>Hero #${h.tokenId}</b> · ${TIER_NAMES[h.tier]} (weight ${w}) · ` +
        `Estimated share: <b>${fmtBnb(est)}</b> ` +
        `<button data-claim="${h.tokenId}" class="btn-claim">Claim</button></div>`;
    }).join("") + `<p class="muted">Each Hero can claim only once. The actual amount is computed from the finalized snapshot.</p>`;
    box.querySelectorAll(".btn-claim").forEach((btn) => {
      btn.addEventListener("click", () => claimSeasonReward(BigInt(btn.dataset.claim)));
    });
  }
}

// ---------------------------------------------------------------------------
// Live previews (no tx)
// ---------------------------------------------------------------------------
function updatePaidTotal() {
  const n = Math.max(0, parseInt($("paidCount").value || "0", 10));
  $("paidTotal").textContent = n > 0 ? `= ${(n * 0.005).toFixed(3)} BNB` : "";
}

function updateMergePreview() {
  const a = heroes.find((h) => h.tokenId.toString() === $("mergeA").value);
  const b = heroes.find((h) => h.tokenId.toString() === $("mergeB").value);
  if (a && b) {
    if (a.tokenId === b.tokenId) { $("mergePreview").textContent = "Pick 2 different Heroes."; return; }
    $("mergePreview").textContent = `→ New Hero Lv ${Math.max(a.level, b.level) + 1} (max Lv10).`;
  } else {
    $("mergePreview").textContent = "";
  }
}

function updateAcceptOdds() {
  const battle = openBattles.find((b) => b.battleId === selectedBattleId);
  const hero = heroes.find((h) => h.tokenId.toString() === $("acceptHero").value);
  const el = $("acceptOdds");
  if (!battle) { el.textContent = selectedBattleId ? "" : ""; return; }
  if (!hero) {
    el.textContent = `Battle #${battle.battleId}: opponent Hero Power ${battle.creatorPower}, bet ${fmtBnb(battle.bet)}. Select your Hero to see your win chance.`;
    return;
  }
  const myPower = Number(hero.power);
  const oppPower = Number(battle.creatorPower);
  const pct = ((myPower / (myPower + oppPower)) * 100).toFixed(1);
  el.innerHTML = `Battle #${battle.battleId}: your Power <b>${myPower}</b> vs opponent Power <b>${oppPower}</b> → ` +
    `your win chance <b>${pct}%</b> (bet ${fmtBnb(battle.bet)}). ` +
    `<button id="btnAcceptBattle">Accept &amp; battle</button>`;
  $("btnAcceptBattle").addEventListener("click", () => acceptBattle(battle.battleId, hero.tokenId, battle.bet));
}

// ---------------------------------------------------------------------------
// Writes (exact ABI function names + params)
// ---------------------------------------------------------------------------
async function mintFree() {
  if (!requireReady()) return;
  await sendTx(() => game.mintFree(), "Free mint");
}

async function mintPaid() {
  if (!requireReady()) return;
  const count = parseInt($("paidCount").value || "0", 10);
  if (!Number.isInteger(count) || count < 1) { setTx("Enter a paid-mint quantity (≥ 1).", true); return; }
  const price = await game.PAID_MINT_PRICE();
  const value = price * BigInt(count);
  await sendTx(() => game.mintPaid(count, { value }), `Paid mint ×${count} (${ethers.formatEther(value)} BNB)`);
}

async function merge() {
  if (!requireReady()) return;
  const a = $("mergeA").value, b = $("mergeB").value;
  if (!a || !b || a === b) { setTx("Pick 2 different Heroes to merge.", true); return; }
  await sendTx(() => game.merge(BigInt(a), BigInt(b)), `Merge #${a} + #${b}`);
}

async function forge() {
  if (!requireReady()) return;
  const id = $("forgeSelect").value;
  if (!id) { setTx("Select a Lv10 Hero to forge.", true); return; }
  await sendTx(() => game.forge(BigInt(id)), `Forge #${id} (random tier: LG 1% / Mythic 5% / Rare 20% / Uncommon 74%)`);
}

async function createBattle() {
  if (!requireReady()) return;
  const id = $("battleHero").value;
  const betStr = $("betAmount").value;
  if (!id) { setTx("Select a Hero to create a battle.", true); return; }
  let bet;
  try { bet = ethers.parseEther(betStr); } catch { setTx("Invalid bet.", true); return; }
  const [min, max] = await Promise.all([game.MIN_BET(), game.MAX_BET()]);
  if (bet < min || bet > max) { setTx(`Bet must be between ${ethers.formatEther(min)} and ${ethers.formatEther(max)} BNB.`, true); return; }
  await sendTx(() => game.createBattle(BigInt(id), { value: bet }), `Create battle with Hero #${id}, bet ${betStr} BNB`);
}

async function acceptBattle(battleId, tokenId, bet) {
  if (!requireReady()) return;
  // Re-read the battle so the bet shown is the live on-chain value.
  const b = await game.battleInfo(battleId);
  if (Number(b.status) !== 0) { setTx(`Battle #${battleId} is no longer open.`, true); await refreshAll(); return; }
  await sendTx(() => game.acceptBattle(battleId, tokenId, { value: b.bet }), `Accept battle #${battleId} with Hero #${tokenId}`);
}

async function cancelBattle(battleId) {
  if (!requireReady()) return;
  await sendTx(() => game.cancelBattle(battleId), `Cancel battle #${battleId} (refund bet + Hero)`);
}

async function snapshotSeason() {
  if (!requireReady()) return;
  await sendTx(() => game.snapshotSeason(), "Snapshot season");
}

async function claimSeasonReward(tokenId) {
  if (!requireReady()) return;
  await sendTx(() => game.claimSeasonReward(tokenId), `Claim season reward for Hero #${tokenId}`);
}

// ---------------------------------------------------------------------------
// Refresh everything
// ---------------------------------------------------------------------------
async function refreshAll() {
  if (!game || !account) return;
  setTx("");
  try {
    const [agentIdBal, freeMinted, mintCount, baseMinted, forgeBal] = await Promise.all([
      registry.balanceOf(account),
      game.freeMinted(account),
      game.mintCountOf(account),
      game.baseMinted(),
      forgeToken.balanceOf(account),
    ]);
    renderWalletInfo(agentIdBal, freeMinted, mintCount, baseMinted, forgeBal);
    $("forgeBalance").textContent = `$FORGE balance: ${ethers.formatEther(forgeBal)} FORGE (winning a battle earns 1,000 FORGE).`;
    $("forgeBalance").dataset.set = "1";
    await loadForgeCaps();
    renderForgeCaps();
    await loadHeroes();
    renderHeroes();
    await loadBattles();
    renderBattles();
    await loadSeason();
    renderSeason();
    log("Data refreshed.");
  } catch (e) {
    setTx(`Failed to load data: ${errMsg(e)}`, true);
    log(`refreshAll failed: ${errMsg(e)}`);
  }
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------
$("btnConnect").addEventListener("click", connectWallet);
$("btnRefresh").addEventListener("click", refreshAll);
$("btnMintFree").addEventListener("click", mintFree);
$("btnMintPaid").addEventListener("click", mintPaid);
$("paidCount").addEventListener("input", updatePaidTotal);
$("btnMerge").addEventListener("click", merge);
$("mergeA").addEventListener("change", updateMergePreview);
$("mergeB").addEventListener("change", updateMergePreview);
$("btnForge").addEventListener("click", forge);
$("btnCreateBattle").addEventListener("click", createBattle);
$("acceptHero").addEventListener("change", updateAcceptOdds);
$("btnSnapshot").addEventListener("click", snapshotSeason);

if (!isDeployed()) {
  $("deployBanner").hidden = false;
  setTx("No contract address yet — paste AGENT_FORGE_ADDRESS into config.js after the testnet deploy.", true);
  log("Config: AGENT_FORGE_ADDRESS not set yet (placeholder 0x0000…).");
} else {
  log("Config has a contract address. Click “Connect wallet” to start.");
}
// Auto-reconnect if the wallet was already authorized (no popup if not).
if (typeof window.ethereum !== "undefined") {
  window.ethereum.request({ method: "eth_accounts", params: [] })
    .then((accs) => { if (accs && accs.length > 0) connectWallet(); })
    .catch(() => { /* not previously authorized — user clicks Connect */ });
}
