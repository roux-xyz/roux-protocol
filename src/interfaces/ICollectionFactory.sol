// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { CollectionData } from "src/types/DataTypes.sol";

interface ICollectionFactory {
    /**
     * @notice create a new edition
     * @param collectionType collection type
     * @param params creation parameters - encode contractUri and init data
     * @return new edition instance
     */
    function create(CollectionData.CollectionType collectionType, bytes calldata params) external returns (address);

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    /**
     * @notice whether the token is an edition
     * @param token token address
     * @return whether the token is an edition
     */
    function isCollection(address token) external view returns (bool);
}
