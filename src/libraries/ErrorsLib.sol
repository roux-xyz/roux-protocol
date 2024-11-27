// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

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

    /// @notice invalid attribution
    error RouxEdition_InvalidAttribution();

    /// @notice invalid collection
    error RouxEdition_InvalidCollection();

    /// @notice invalid caller
    error RouxEdition_InvalidCaller();

    /// @notice invalid extension
    error RouxEdition_InvalidExtension();

    /// @notice token has parent
    error RouxEdition_HasParent();

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

    /// @notice controller is paused
    error Controller_Paused();

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

    /// @notice mint not started
    error Collection_MintNotStarted();

    /// @notice mint ended
    error Collection_MintEnded();

    /// @notice multi edition collection price mismatch
    error Collection_InvalidPrice();

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

    /// @notice
    error RouxEditionFactory_DenyList();

    /* ------------------------------------------------- */
    /* CollectionFactory                                 */
    /* ------------------------------------------------- */

    /// @notice invalid collection type
    error CollectionFactory_InvalidCollectionType();

    /// @notice denylist
    error CollectionFactory_DenyList();

    /// @notice collection curator already set
    error Collection_CuratorAlreadySet();

    /* ------------------------------------------------- */
    /* RouxMintPortal                                    */
    /* ------------------------------------------------- */

    /// @notice invalid params
    error RouxMintPortal_InvalidParams();

    /// @notice invalid caller
    error RouxMintPortal_InvalidCaller();

    /// @notice invalid token
    error RouxMintPortal_InvalidToken();

    /// @notice gated mint
    error RouxMintPortal_GatedMint();

    /// @notice insufficient balance
    error RouxMintPortal_InsufficientBalance();

    /* ------------------------------------------------- */
    /* RouxCommunityEdition                                */
    /* ------------------------------------------------- */

    /// @notice not allowed
    error RouxCommunityEdition_NotAllowed();

    /// @notice add window closed
    error RouxCommunityEdition_AddWindowClosed();

    /// @notice invalid add window
    error RouxCommunityEdition_InvalidAddWindow();

    /// @notice max adds per address exceeded
    error RouxCommunityEdition_ExceedsMaxAddsPerAddress();

    /// @notice exceeds max tokens
    error RouxCommunityEdition_ExceedsMaxTokens();
}
