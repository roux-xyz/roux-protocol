// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { ICollection } from "src/core/interfaces/ICollection.sol";

interface IRouxMintPortal {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    /// @notice invalid edition
    error RouxMintPortal_InvalidEdition();

    /// @notice invalid collection
    error RouxMintPortal_InvalidCollection();

    /* -------------------------------------------- */
    /* write functions                              */
    /* -------------------------------------------- */

    /**
     * @notice deposit underlying and mint rUSDC
     * @param to token receiver
     * @param amount amount to mint
     */
    function deposit(address to, uint256 amount) external;

    /**
     * @notice mint roux edition
     * @param to token receiver
     * @param edition edition address
     * @param id token id
     * @param quantity quantity
     * @param extension extension
     * @param referrer referrer
     * @param data additional data
     *
     * @dev if extension is zero, the default price will be used, if extension is provided,
     *      the extension will be used to get the price, but not approve the mint. Mint is
     *      still approved by the RouxEdition or Collection contract.
     */
    function mintEdition(
        address to,
        IRouxEdition edition,
        uint256 id,
        uint256 quantity,
        address extension,
        address referrer,
        bytes calldata data
    )
        external;

    /**
     * @notice batch mint edition
     * @param to token receiver
     * @param edition editions
     * @param ids ids
     * @param quantities quantities
     * @param extensions extensions
     * @param referrer referrer
     * @param data additional data
     *
     * @dev if extension is zero, the default price will be used, if extension is provided,
     *      the extension will be used to get the price, but not approve the mint. Mint is
     *      still approved by the RouxEdition or Collection contract.
     */
    function batchMintEdition(
        address to,
        IRouxEdition edition,
        uint256[] calldata ids,
        uint256[] calldata quantities,
        address[] calldata extensions,
        address referrer,
        bytes calldata data
    )
        external;

    /**
     * @notice redeem free edition mint
     * @param edition edition address
     * @param id token id
     * @param referrer referrer
     * @param data additional data
     */
    function redeemEditionMint(address edition, uint256 id, address referrer, bytes calldata data) external;

    /**
     * @notice mint collection
     * @param to token receiver
     * @param collection collection address
     * @param extension extension
     * @param referrer referrer
     * @param data additional data
     *
     * @dev if extension is zero, the default price will be used, if extension is provided,
     *      the extension will be used to get the price, but not approve the mint. Mint is
     *      still approved by the RouxEdition or Collection contract.
     */
    function mintCollection(
        address to,
        ICollection collection,
        address extension,
        address referrer,
        bytes calldata data
    )
        external;
}
