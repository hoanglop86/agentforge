// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ForgeToken ($FORGE)
/// @notice Reward token for the AgentForge game. Fixed supply of 1,000,000,000
///         FORGE, minted once to the deploying game contract. No further
///         minting is possible.
contract ForgeToken is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether;

    constructor() ERC20("AgentForge", "FORGE") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
