// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IFactory } from "./IFactory.sol";

interface ICollectionFactory is IFactory {
    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    event NewCollection(address instance);

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    function isCollection(address token) external view returns (bool);

    function getCollections() external view returns (address[] memory);
}
