// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

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

    /* ------------------------------------------------- */
    /* write functions                                   */
    /* ------------------------------------------------- */

    /**
     * @notice create a new edition
     * @param params creation parameters - encode contractUri and init data
     * @return new edition instance
     */
    function create(bytes calldata params) external returns (address);
}
