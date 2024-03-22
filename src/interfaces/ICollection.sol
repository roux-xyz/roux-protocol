// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface ICollection is IERC721 {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    error OnlyOwner();

    error InvalidItems();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    event ItemAdded(address target, uint256 itemId);

    event ItemRemoved(address target, uint256 itemId);

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function collection() external view returns (address[] memory, uint256[] memory);

    function collectionPrice() external view returns (uint256);

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function mint() external payable returns (uint256);
}
