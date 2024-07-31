// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.26;

library ErrorsLib {
    /* ------------------------------------------------- */
    /* RouxEdition                                       */
    /* ------------------------------------------------- */

    /// @notice invalid params
    error RouxEdition_InvalidParams();

    /// @notice invalid token id
    error RouxEdition_InvalidTokenId();

    /// @notice max supply exceeded
    error RouxEdition_MaxSupplyExceeded();

    /// @notice invalid currency
    error RouxEdition_InvalidCurrency();

    /// @notice gated mint
    error RouxEdition_GatedMint();

    /// @notice only allowlist
    error RouxEdition_OnlyAllowlist();

    /// @notice invalid attribution
    error RouxEdition_InvalidAttribution();

    /// @notice invalid collection
    error RouxEdition_InvalidCollection();

    /// @notice invalid caller
    error RouxEdition_InvalidCaller();

    /// @notice invalid extension
    error RouxEdition_InvalidExtension();

    /// @notice uri is frozen
    error RouxEdition_UriFrozen();

    /* ------------------------------------------------- */
    /* Controller                                        */
    /* ------------------------------------------------- */

    /// @notice transfer failed
    error Controller_TransferFailed();

    /// @notice invalid funds recipient
    error Controller_InvalidFundsRecipient();

    /// @notice invalid profit share value
    error Controller_InvalidProfitShare();

    /// @notice invalid array length
    error Controller_InvalidArrayLength();

    /* ------------------------------------------------- */
    /* Collection                                        */
    /* ------------------------------------------------- */

    /// @notice invalid extension
    error Collection_InvalidExtension();

    /// @notice gated mint
    error Collection_GatedMint();

    /// @notice invalid edition
    error Collection_InvalidEdition();

    /// @notice invalid items
    error Collection_InvalidItems();

    /// @notice invalid caller
    error Collection_InvalidCaller();

    /// @notice invalid collection size
    error Collection_InvalidCollectionSize();

    /* ------------------------------------------------- */
    /* Registry                                          */
    /* ------------------------------------------------- */

    /// @notice max depth exceeded
    error Registry_MaxDepthExceeded();

    /// @notice invalid attribution
    error Registry_InvalidAttribution();

    /* ------------------------------------------------- */
    /* RouxEditionFactory                                */
    /* ------------------------------------------------- */

    /// @notice collection factory already set
    error RouxEditionFactory_CollectionFactoryAlreadySet();

    /* ------------------------------------------------- */
    /* CollectionFactory                                 */
    /* ------------------------------------------------- */

    /// @notice invalid collection type
    error CollectionFactory_InvalidCollectionType();

    /// @notice only allowlist
    error CollectionFactory_OnlyAllowlist();
}
