// AgentForge — frontend config.
// HOW TO GO LIVE: after deploying AgentForge to BSC testnet, paste the
// deployed contract address into AGENT_FORGE_ADDRESS below (and set
// CHAIN_ID to 97 for testnet, or 56 for mainnet). No other file needs
// changing: the Agent ID registry and $FORGE token addresses are read
// on-chain from the game contract (registry() / token()).

const CONFIG = {
  // BSC testnet = 97. Mainnet = 56 — LIVE on mainnet since 19/11/2026.
  CHAIN_ID: 56,
  CHAIN_ID_MAINNET: 56,

  // Deployed AgentForge contract address.
  // Mainnet deploy 19/11/2026 (45-day season, ends 10:19 VN 03/01/2027): 0xa65944f2093e6dcfd1d1a7a4f6744f924068f878
  // Testnet deploy 19/11/2026 (7-day season): 0x69Fd48117Ec4f920501B573096133fefEA2c6096
  // (see docs/MAINNET_DEPLOY.md and docs/TESTNET_DEPLOY.md). UI refuses to call the contract until a real address is set.
  AGENT_FORGE_ADDRESS: "0xa65944f2093e6dcfd1d1a7a4f6744f924068f878",

  // Agent ID registry (mainnet). Only used as a fallback hint in the UI;
  // the live check reads registry() from the game contract.
  AGENT_ID_REGISTRY_MAINNET: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F",

  // Chain metadata for wallet_addEthereumChain (used only if the wallet
  // is on the wrong network and cannot switch on its own).
  CHAINS: {
    97: {
      chainId: "0x61",
      chainName: "BNB Smart Chain Testnet",
      nativeCurrency: { name: "tBNB", symbol: "tBNB", decimals: 18 },
      rpcUrls: ["https://data-seed-prebsc-1-s1.binance.org:8545"],
      blockExplorerUrls: ["https://testnet.bscscan.com"],
    },
    56: {
      chainId: "0x38",
      chainName: "BNB Smart Chain",
      nativeCurrency: { name: "BNB", symbol: "BNB", decimals: 18 },
      rpcUrls: ["https://bsc-dataseed.binance.org"],
      blockExplorerUrls: ["https://bscscan.com"],
    },
  },
};
