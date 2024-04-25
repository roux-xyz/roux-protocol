// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IEditionMinter {
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

    /**
     * @notice mint
     * @param to address receiving minted tokens
     * @param edition edition
     * @param id token id
     * @param quantity quantity
     * @param data optional data
     */
    function mint(address to, address edition, uint256 id, uint256 quantity, bytes memory data) external payable;

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
