// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ICollectionFactory {
    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    error OnlyAllowlist();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    event NewCollection(address indexed instance);

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    function isCollection(address token) external view returns (bool);

    function getCollections() external view returns (address[] memory);
}
