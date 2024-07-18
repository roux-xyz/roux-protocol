// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IEditionExtension {
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

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */
    /**
     * @notice get proxy implementation
     * @return implementation address
     *
     * @dev do not remove this function
     */
    function getImplementation() external view returns (address);

    /**
     * @notice upgrade proxy
     * @param newImplementation new implementation contract
     * @param data optional calldata
     *
     * @dev do not remove this function
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external;
}
