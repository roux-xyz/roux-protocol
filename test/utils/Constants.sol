// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

abstract contract Constants {
    uint128 constant TEST_TOKEN_MAX_SUPPLY = type(uint128).max;
    uint128 constant TEST_TOKEN_PRICE = 0.05 ether;
    uint40 constant TEST_TOKEN_MINT_DURATION = 365 days;
    string constant TEST_TOKEN_URI = "https://token.com/uri";
    string constant TEST_CONTRACT_URI = "https://contract.com/uri";
    string constant TEST_COLLECTION_NAME = "Test Collection";
    string constant TEST_COLLECTION_SYMBOL = "TST";
    uint16 constant TEST_PROFIT_SHARE = 350;
    uint256 constant MAX_FORK_DEPTH = 8;
}
