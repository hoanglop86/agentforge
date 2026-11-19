// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockAgentIdRegistry} from "../src/MockAgentIdRegistry.sol";
import {AgentForge} from "../src/AgentForge.sol";

/// @notice Deploy AgentForge to BSC testnet (chain 97).
/// @dev Run with tBNB in the deployer wallet first (see ../TESTNET_RUNBOOK.md).
///      Env: DEPLOYER_PK (hex, no 0x prefix needed — cast-style "0x..." also works),
///      SEASON_DURATION (seconds, default 604800 = 7 days).
///      Example:
///        DEPLOYER_PK=$(cat ../.deployer-key-testnet) SEASON_DURATION=604800 \
///        forge script script/Deploy.s.sol --rpc-url https://bsc-testnet.publicnode.com \
///          --broadcast -vvvv
contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("DEPLOYER_PK");
        uint256 seasonDuration = vm.envOr("SEASON_DURATION", uint256(604800));

        vm.startBroadcast(pk);
        MockAgentIdRegistry registry = new MockAgentIdRegistry();
        AgentForge game = new AgentForge(address(registry), seasonDuration);
        vm.stopBroadcast();

        console.log("MockAgentIdRegistry:", address(registry));
        console.log("AgentForge:", address(game));
        console.log("ForgeToken:", address(game.token()));
        console.log("seasonEnd:", game.seasonEnd());
        console.log("seasonDuration:", seasonDuration);
    }
}
