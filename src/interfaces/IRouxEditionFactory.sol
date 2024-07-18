// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IRouxEditionFactory {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    /**
     * @notice only allowlist
     */
    error OnlyAllowlist();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    /**
     * @notice new edition
     * @param instance edition instance
     */
    event NewEdition(address indexed instance);

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    /**
     * @notice whether the token is an edition
     * @param token token address
     * @return whether the token is an edition
     */
    function isEdition(address token) external view returns (bool);

    /**
     * @notice get all editions
     * @return all editions
     */
    function getEditions() external view returns (address[] memory);

    /**
     * @notice check if caller can create an edition
     * @param caller caller
     */
    function canCreate(address caller) external view returns (bool);

    /* -------------------------------------------- */
    /* write functions                              */
    /* -------------------------------------------- */

    /**
     * @notice create a new edition
     * @param params creation parameters - encode contractUri and init data
     * @return new edition instance
     */
    function create(bytes calldata params) external returns (address);
}
