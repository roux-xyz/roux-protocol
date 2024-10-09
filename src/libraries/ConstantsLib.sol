// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

/// @dev basis point scale
uint256 constant BASIS_POINT_SCALE = 10_000;

/// @dev maximum depth of attribution tree
uint256 constant MAX_CHILDREN = 8;

/// @dev collection salt used for erc6551 implementation
bytes32 constant ROUX_SINGLE_EDITION_COLLECTION_SALT = keccak256("ROUX_SINGLE_EDITION_COLLECTION");

/// @dev collection salt used for erc6551 implementation
bytes32 constant ROUX_MULTI_EDITION_COLLECTION_SALT = keccak256("ROUX_MULTI_EDITION_COLLECTION");

/// @dev default uri for unrevealed edition tokens
string constant DEFAULT_TOKEN_URI = "";

/// @dev maximum collection size
uint256 constant MAX_SINGLE_EDITION_COLLECTION_SIZE = 10;

/// @dev maximum collection size
uint256 constant MAX_MULTI_EDITION_COLLECTION_SIZE = 10;

/// @dev erc6551 registry
address constant ERC_6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;

/// @dev usdc base sepolia
/// todo: is this being used?
address constant USDC_BASE_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
