// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { IController } from "src/interfaces/IController.sol";
import { EditionData } from "src/types/DataTypes.sol";

interface IRouxEdition {
    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    /**
     * @notice get creator
     * @param id token id
     * @return creator address
     */
    function creator(uint256 id) external view returns (address);

    /**
     * @notice get current token id
     * @return current token id
     */
    function currentToken() external view returns (uint256);

    /**
     * @notice get currency address
     * @return currency address
     */
    function currency() external view returns (address);

    /**
     * @notice get total supply for a given token id
     * @param id token id
     * @return total supply
     */
    function totalSupply(uint256 id) external view returns (uint256);

    /**
     * @notice get max supply for a given token id
     * @param id token id
     * @return max supply
     */
    function maxSupply(uint256 id) external view returns (uint256);

    /**
     * @notice get uri for a given token id
     * @param id token id
     * @return uri
     */
    function uri(uint256 id) external view returns (string memory);

    /**
     * @notice contract uri
     * @return contract uri
     */
    function contractURI() external view returns (string memory);

    /**
     * @notice check if token exists
     * @param id token id
     * @return true if token exists
     */
    function exists(uint256 id) external view returns (bool);

    /**
     * @notice check if extension is valid for a token
     * @param id token id
     * @param extension extension address
     * @return true if extension is valid
     */
    function isRegisteredExtension(uint256 id, address extension) external view returns (bool);

    /**
     * @notice check if collection is valid for a collection id
     * @param collection collection address
     * @return true if collection is valid
     */
    function isRegisteredCollection(address collection) external view returns (bool);

    /**
     * @notice get default price for a token
     * @param id token id
     * @return default price
     */
    function defaultPrice(uint256 id) external view returns (uint128);

    /**
     * @notice check if a token is gated
     * @param id token id
     * @return true if token is gated
     *
     * @dev a token can be gated on `add`, and then disabled using `disableGate`, but cannot
     *      be gated once added - this is to prevent an ungated token from being included in
     *      a multi edition collection, and then gated, which would make the entire
     *      collection unmintable as it would fail the `multiCollectionMintEligible` check
     */
    function isGated(uint256 id) external view returns (bool);

    /**
     * @notice get default mint parameters for a token
     * @param id token id
     * @return default mint parameters
     */
    function defaultMintParams(uint256 id) external view returns (EditionData.MintParams memory);

    /**
     * @notice check if token can be minted as part of a multi collection
     * @param id token id
     * @param currency_ collection currency
     * @return true if token can be minted as part of a multi collection
     * @dev used by MultiEditionCollection to confirm token eligibility for multi collection inclusion
     */
    function multiCollectionMintEligible(uint256 id, address currency_) external view returns (bool);

    /* -------------------------------------------- */
    /* write functions                              */
    /* -------------------------------------------- */

    /**
     * @notice add a new token
     * @param p AddParams struct containing token parameters
     * @return new token id
     *
     * @dev parent attributes must include a valid edtion and token id - if one or both are zero, the registry
     *      will not be updated ~ the call does not revert if one or the other is set and the other is zero
     */
    function add(EditionData.AddParams calldata p) external returns (uint256);

    /**
     * @notice mint a token
     * @param to token receiver
     * @param id token id
     * @param quantity number of tokens to mint
     * @param referrer referrer address
     * @param extension extension address
     * @param data additional data
     */
    function mint(
        address to,
        uint256 id,
        uint256 quantity,
        address referrer,
        address extension,
        bytes calldata data
    )
        external
        payable;

    /**
     * @notice batch mint tokens for a single edition collection
     * @param to token receiver
     * @param ids array of token ids
     * @param quantities array of quantities
     * @param extensions array of extensions
     * @param referrer referrer address
     * @param data additional data
     */
    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory quantities,
        address[] memory extensions,
        address referrer,
        bytes calldata data
    )
        external
        payable;

    /**
     * @notice mint tokens for a single edition collection
     * @param to token receiver
     * @param ids array of token ids
     * @param data additional data
     *
     * @dev used by SingleEditionCollection to batch mint tokens to token bound account
     *      - edition owner must register the collection using `setCollection`
     *      - bypasses validation that token is ungated, which enables tokens that can
     *        only be minted as part of a collection
     *      - bypasses validation that token exists
     */
    function collectionSingleMint(address to, uint256[] memory ids, bytes calldata data) external payable;

    /**
     * @notice mint a token for a multi edition collection
     * @param to token receiver
     * @param id token id
     * @param data additional data
     *
     * @dev used by MultiEditionCollection to mint single edition token to token bound account
     *      - validates that collection was created by `CollectionFactory`
     *      - validates that token exists
     */
    function collectionMultiMint(address to, uint256 id, bytes calldata data) external payable;

    /**
     * @notice admin mint tokens
     * @param to token receiver
     * @param id token id
     * @param quantity number of tokens to mint
     * @param data additional data
     *
     * @dev only callable by owner - bypasses all validations
     */
    function adminMint(address to, uint256 id, uint256 quantity, bytes calldata data) external;

    /**
     * @notice admin batch mint tokens
     * @param to token receiver
     * @param ids array of token ids
     * @param quantities array of quantities
     * @param data additional data
     *
     * @dev only callable by owner - bypasses all validations
     */
    function adminBatchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory quantities,
        bytes calldata data
    )
        external;
}
