// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ICollection {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */
    error InvalidItems();

    error CuratorAlreadyInitialized();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    event ItemAdded(address target, uint256 itemId);

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function collection() external view returns (address[] memory, uint256[] memory);

    function collectionPrice() external view returns (uint256);

    function curator() external view returns (address);

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function mint() external payable returns (uint256);
}
