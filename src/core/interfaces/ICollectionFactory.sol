// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionData } from "src/types/DataTypes.sol";

interface ICollectionFactory {
    /**
     * @notice create a new edition - single edition
     * @param params creation parameters - encode contractUri and init data
     * @return new edition instance
     */
    function createSingle(CollectionData.SingleEditionCreateParams calldata params) external returns (address);

    /**
     * @notice create a new edition - multi edition
     * @param params creation parameters - encode contractUri and init data
     * @return new edition instance
     */
    function createMulti(CollectionData.MultiEditionCreateParams calldata params) external returns (address);

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    /**
     * @notice whether the token is an edition
     * @param token token address
     * @return whether the token is an edition
     */
    function isCollection(address token) external view returns (bool);

    /**
     * @notice get total collections
     * @return total collections
     */
    function totalCollections() external view returns (uint256);
}
