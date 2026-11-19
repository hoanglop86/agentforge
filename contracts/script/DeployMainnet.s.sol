// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AgentForge} from "../src/AgentForge.sol";

/// @notice Deploy AgentForge to BSC MAINNET (chain 56).
/// @dev Mainnet MUST use the REAL Agent ID registry — do NOT deploy the mock.
///      Env: DEPLOYER_PK (hex), REGISTRY (default = real mainnet registry),
///      SEASON_DURATION (seconds, default 604800 = 7 days, same as testnet).
///      NOTE: SPEC.md says mainnet season is 30 days; the 7-day default here
///      follows the 19/11 mainnet prep instruction (match testnet). Set
///      SEASON_DURATION=2592000 explicitly if the 30-day season is chosen.
///      Example (dry-run simulation, no broadcast):
///        DEPLOYER_PK=$(cat ../.deployer-key-mainnet) \
///        forge script script/DeployMainnet.s.sol --rpc-url https://bsc-dataseed.binance.org
///      Real deploy (only after VO funds the deployer):
///        DEPLOYER_PK=$(cat ../.deployer-key-mainnet) SEASON_DURATION=604800 \
///        forge script script/DeployMainnet.s.sol --rpc-url https://bsc-dataseed.binance.org \
///          --broadcast --with-gas-price 100000000 --priority-gas-price 100000000 --start-fresh
contract DeployMainnet is Script {
    address constant MAINNET_REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PK");
        address registry = vm.envOr("REGISTRY", MAINNET_REGISTRY);
        uint256 seasonDuration = vm.envOr("SEASON_DURATION", uint256(604800));

        require(registry != address(0), "registry zero");
        require(registry == MAINNET_REGISTRY, "mainnet must use the real Agent ID registry");

        vm.startBroadcast(pk);
        AgentForge game = new AgentForge(registry, seasonDuration);
        vm.stopBroadcast();

        console.log("AgentForge:", address(game));
        console.log("ForgeToken:", address(game.token()));
        console.log("registry:", address(game.registry()));
        console.log("seasonEnd:", game.seasonEnd());
        console.log("seasonDuration:", seasonDuration);
    }
}
