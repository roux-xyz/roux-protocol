// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface IEditionExtension {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    /**
     * @notice insufficient funds
     */
    error InsufficientFunds();

    /**
     * @notice invalid mint params
     */
    error InvalidMintParams();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    /**
     * @notice emitted when mint params are updated
     *
     * @param edition edition address
     * @param id edition id
     * @param mintParams mint params
     */
    event MintParamsUpdated(address indexed edition, uint256 indexed id, bytes mintParams);

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @notice get token price
     * @param edition edition
     * @param id token id
     * @return token price
     */
    function price(address edition, uint256 id) external view returns (uint128);

    /**
     * @notice approve mint
     * @param id id
     * @param quantity quantity
     * @param operator operator
     * @param account account
     * @param data data
     */
    function approveMint(
        uint256 id,
        uint256 quantity,
        address operator,
        address account,
        bytes calldata data
    )
        external
        returns (uint256);

    /**
     * @notice supports interface
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @notice set mint params
     * @param id token id
     * @param params mint params
     *
     * @dev must be called via edition
     */
    function setMintParams(uint256 id, bytes calldata params) external;
}
