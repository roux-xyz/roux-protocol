// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.25;

import { EditionData } from "src/types/DataTypes.sol";

contract Defaults {
    // edition
    uint128 public constant MAX_SUPPLY = type(uint128).max;
    uint128 public constant TOKEN_PRICE = 2 * 10 ** 6; // 2 USDC;
    uint40 public constant MINT_DURATION = 365 days;
    string public constant TOKEN_URI = "https://token.com/uri";
    string public constant CONTRACT_URI = "https://contract.com/uri";
    uint16 public constant PROFIT_SHARE = 4_000;

    // collection
    string public constant COLLECTION_NAME = "Test Collection";
    string public constant COLLECTION_SYMBOL = "TST";
    string public constant COLLECTION_URI = "https://collection.com/uri";
    uint128 public constant SINGLE_EDITION_COLLECTION_PRICE = 5 * 10 ** 6; // 5 USDC;
}
