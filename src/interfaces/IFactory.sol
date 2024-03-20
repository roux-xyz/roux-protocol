// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IFactory {
    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    error OnlyOwner();

    /* -------------------------------------------- */
    /* write functions                              */
    /* -------------------------------------------- */

    function create(bytes calldata params) external returns (address);
}
