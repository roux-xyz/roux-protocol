// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IRouxCreator is IERC1155 {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    error InvalidTokenId();

    error MaxSupplyExceeded();

    error InsufficientFunds();

    error TransferFailed();

    error OnlyOwner();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    event TokenAdded(uint256 indexed id);

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    function price(uint256 id) external view returns (uint256);

    function totalSupply(uint256 id) external view returns (uint256);

    function owner() external view returns (address);

    function creator() external view returns (address);

    function tokenCount() external view returns (uint256);

    function maxSupply(uint256 id) external view returns (uint256);

    function uri(uint256 id) external view returns (string memory);

    function attribution(uint256 id) external view returns (address, uint96);

    /* -------------------------------------------- */
    /* write functions                              */
    /* -------------------------------------------- */

    function mint(address to, uint256 id, uint256 quantity) external payable;

    function add(uint256 maxSupply, uint256 price_, string memory tokenUri) external returns (uint256);

    function add(
        uint256 maxSupply,
        uint256 price_,
        string memory tokenUri,
        address parentContract,
        uint96 parentId
    )
        external
        returns (uint256);
}
