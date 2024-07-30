// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.26;

/// @dev basis point scale
uint256 constant BASIS_POINT_SCALE = 10_000;

/// @dev maximum depth of attribution tree
uint256 constant MAX_NUM_FORKS = 8;

/// @dev collection salt used for erc6551 implementation
bytes32 constant ROUX_SINGLE_EDITION_COLLECTION_SALT = keccak256("ROUX_SINGLE_EDITION_COLLECTION");

/// @dev collection salt used for erc6551 implementation
bytes32 constant ROUX_MULTI_EDITION_COLLECTION_SALT = keccak256("ROUX_MULTI_EDITION_COLLECTION");

/// @dev default uri for unrevealed edition tokens
string constant DEFAULT_TOKEN_URI = "";
