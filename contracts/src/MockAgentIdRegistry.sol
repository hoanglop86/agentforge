// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title MockAgentIdRegistry
/// @notice TESTNET-ONLY stand-in for the real Agent ID registry. Anyone can
///         mint a test Agent ID, so the game can be exercised end to end on
///         BSC testnet. Never deploy this on mainnet: on mainnet the game
///         points at the real registry (0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F).
contract MockAgentIdRegistry is ERC721 {
    uint256 private _nextTokenId = 1;

    constructor() ERC721("Mock Agent ID", "AGENTID") {}

    /// @notice Mint a test Agent ID to `to`. Returns the new token id.
    function mint(address to) external returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _mint(to, tokenId);
    }

    /// @notice Mint a test Agent ID to the caller.
    function mintSelf() external returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);
    }
}
