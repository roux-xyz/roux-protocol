// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface ICollectionExtension {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    /**
     * @notice insufficient funds
     */
    error InsufficientFunds();

    /**
     * @notice invalid params length
     */
    error InvalidParamsLength();

    /**
     * @notice invalid mint params
     */
    error InvalidMintParams();

    /**
     * @notice already minted
     */
    error AlreadyMinted();

    /**
     * @notice batch id does not exist
     */
    error MintParamsNotSet();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    /**
     * @notice emitted when mint params are updated
     * @param id edition id
     * @param mintParams mint params
     */
    event MintParamsUpdated(uint256 id, bytes mintParams);

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @notice get collection price
     */
    function price() external view returns (uint128);

    /**
     * @notice approve mint
     * @param operator operator
     * @param account account
     * @param data data
     */
    function approveMint(address operator, address account, bytes calldata data) external returns (uint128);

    /**
     * @notice supports interface
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @notice set mint params
     * @param params mint params
     *
     * @dev must be called via edition
     */
    function setCollectionMintParams(bytes calldata params) external;
}
