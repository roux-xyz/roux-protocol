// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

interface IRouxEditionFactory {
    /* ------------------------------------------------- */
    /* view functions                                    */
    /* ------------------------------------------------- */

    /**
     * @notice whether the token is an edition
     * @param token token address
     * @return whether the token is an edition
     */
    function isEdition(address token) external view returns (bool);

    /**
     * @notice number of editions
     * @return number of editions
     */
    function totalEditions() external view returns (uint256);

    /* ------------------------------------------------- */
    /* write functions                                   */
    /* ------------------------------------------------- */

    /**
     * @notice create a new edition
     * @param params creation parameters - encode contractUri and init data
     * @return new edition instance
     */
    function create(bytes calldata params) external returns (address);

    /**
     * @notice create a new community edition
     * @param params creation parameters - encode contractUri and init data
     * @return new edition instance
     */
    function createCommunity(bytes calldata params) external returns (address);
}
