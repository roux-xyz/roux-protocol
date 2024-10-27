// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ICollection } from "src/interfaces/ICollection.sol";
import { IExtension } from "src/interfaces/IExtension.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IController } from "src/interfaces/IController.sol";
import { Collection } from "src/abstracts/Collection.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { CollectionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, CURATOR_FEE } from "src/libraries/FeesLib.sol";
import { ROUX_MULTI_EDITION_COLLECTION_SALT, MAX_MULTI_EDITION_COLLECTION_SIZE } from "src/libraries/ConstantsLib.sol";

/**
 * @title multi edition collection
 * @author rouxa
 * @custom:version 1.0
 * @custom:security-contact mp@roux.app
 */
contract MultiEditionCollection is Collection {
    using SafeTransferLib for address;
    using LibBitmap for LibBitmap.Bitmap;

    /* ------------------------------------------------- */
    /* constants                                         */
    /* ------------------------------------------------- */

    /**
     * @notice MultiEditionCollection storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("multiEditionCollection.multiEditionCollectionStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant MULTI_EDITION_COLLECTION_STORAGE_SLOT =
        0x80f0f9485e96d2fa1d83203f8bbee993202c4d0ad979d7d0de8ea7e7c4dcbd00;

    /* ------------------------------------------------- */
    /* structures                                        */
    /* ------------------------------------------------- */

    /**
     * @notice Collection storage
     * @custom:storage-location erc7201:multiEditionCollection.multiEditionCollectionStorage
     * @param itemTargets target edition addresses
     * @param itemIds array of item IDs in the collection
     * @param mintParams mint parameters
     * @param collectionFeeRecipient rewards recipient address
     */
    struct MultiEditionCollectionStorage {
        address[] itemTargets;
        uint256[] itemIds;
        CollectionData.MultiEditionMintParams mintParams;
        address collectionFeeRecipient;
    }

    /* ------------------------------------------------- */
    /* constructor                                       */
    /* ------------------------------------------------- */

    /**
     * @notice constructor
     * @param erc6551registry registry
     * @param accountImplementation initial erc6551 account implementation
     * @param editionFactory roux edition factory
     * @param controller controller
     */
    constructor(
        address erc6551registry,
        address accountImplementation,
        address editionFactory,
        address controller
    )
        Collection(erc6551registry, accountImplementation, editionFactory, controller)
    { }

    /* ------------------------------------------------- */
    /* initializer                                       */
    /* ------------------------------------------------- */

    /**
     * @notice initialize collection
     * @param p parameters for initializing the collection
     */
    function initialize(CollectionData.MultiEditionCreateParams calldata p) external initializer {
        CollectionStorage storage $ = _collectionStorage();
        MultiEditionCollectionStorage storage $$ = _multiEditionCollectionStorage();

        // factory will transfer ownership to its caller
        _initializeOwner(msg.sender);

        // validate length
        if (p.itemTargets.length != p.itemIds.length) revert ErrorsLib.Collection_InvalidItems();

        // validate collection size
        if (p.itemIds.length > MAX_MULTI_EDITION_COLLECTION_SIZE) {
            revert ErrorsLib.Collection_InvalidCollectionSize();
        }

        // set mintParams
        $$.mintParams = CollectionData.MultiEditionMintParams({ mintStart: p.mintStart, mintEnd: p.mintEnd });

        // set rewards recipient
        $$.collectionFeeRecipient = p.collectionFeeRecipient;

        // set items
        $$.itemTargets = p.itemTargets;
        $$.itemIds = p.itemIds;

        // set state vars
        $.name = p.name;
        $.symbol = p.symbol;
        $.uri = p.uri;
        $.currency = IController(_controller).currency();

        for (uint256 i = 0; i < p.itemIds.length; ++i) {
            // verify editions
            if (!_editionFactory.isEdition($$.itemTargets[i])) revert ErrorsLib.Collection_InvalidItems();

            // verify items
            if (!IRouxEdition($$.itemTargets[i]).multiCollectionMintEligible($$.itemIds[i], $.currency)) {
                revert ErrorsLib.Collection_InvalidItems();
            }
        }

        // approve controller to spend funds
        IERC20($.currency).approve(address(_controller), type(uint256).max);
    }

    /* ------------------------------------------------- */
    /* storage                                           */
    /* ------------------------------------------------- */

    /**
     * @notice MultiEditionCollection storage
     * @return $$ MultiEditionCollection storage location
     */
    function _multiEditionCollectionStorage() internal pure returns (MultiEditionCollectionStorage storage $$) {
        assembly {
            $$.slot := MULTI_EDITION_COLLECTION_STORAGE_SLOT
        }
    }

    /* ------------------------------------------------- */
    /* view                                              */
    /* ------------------------------------------------- */

    /// @inheritdoc ICollection
    function price() external view override returns (uint256) {
        MultiEditionCollectionStorage storage $$ = _multiEditionCollectionStorage();

        uint256 total;
        for (uint256 i = 0; i < $$.itemTargets.length; ++i) {
            total += IRouxEdition($$.itemTargets[i]).defaultPrice($$.itemIds[i]);
        }

        return total;
    }

    /// @inheritdoc ICollection
    function collection() external view override returns (address[] memory, uint256[] memory) {
        MultiEditionCollectionStorage storage $$ = _multiEditionCollectionStorage();

        address[] memory itemTargets = $$.itemTargets;
        uint256[] memory itemIds = $$.itemIds;

        return (itemTargets, itemIds);
    }

    /**
     * @notice get collection fee recipient
     * @return collection fee recipient
     */
    function collectionFeeRecipient() external view returns (address) {
        return _multiEditionCollectionStorage().collectionFeeRecipient;
    }

    /* ------------------------------------------------- */
    /* write                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc ICollection
    function mint(
        address to,
        address extension,
        address referrer,
        bytes calldata data
    )
        external
        override
        nonReentrant
        returns (uint256)
    {
        // extensions cannot discount the computed price
        (uint256 computedPrice, uint256[] memory prices) = _prices();

        if (extension != address(0)) {
            if (!_isRegisteredExtension(extension)) revert ErrorsLib.Collection_InvalidExtension();

            // approve mint (extension price should be same as computed price in multi edition collection)
            IExtension(extension).approveMint({ id: 0, quantity: 1, operator: msg.sender, account: to, data: data });
        } else {
            // check gate ~ if gate is enabled, must be minted via extension
            if (_collectionStorage().gate) revert ErrorsLib.Collection_GatedMint();
        }

        return _mint(to, referrer, computedPrice, prices);
    }

    /**
     * @notice convert mint
     * @param to address to mint to
     * @return collection token id
     *
     * @dev users holding the constituent tokens can convert them to the collection for no additional cost
     */
    function convertMint(address to) external returns (uint256) {
        CollectionStorage storage $ = _collectionStorage();
        MultiEditionCollectionStorage storage $$ = _multiEditionCollectionStorage();

        if (block.timestamp < $$.mintParams.mintStart) revert ErrorsLib.Collection_MintNotStarted();
        if (block.timestamp > $$.mintParams.mintEnd) revert ErrorsLib.Collection_MintEnded();

        // increment token id
        uint256 collectionTokenId = ++$.tokenIds;

        // mint token bound account
        address account = _mintTba(to, collectionTokenId, ROUX_MULTI_EDITION_COLLECTION_SALT);

        // mint
        for (uint256 i = 0; i < $$.itemTargets.length; ++i) {
            address edition = $$.itemTargets[i];
            uint256 id = $$.itemIds[i];

            // transfer token to tba
            IERC1155(edition).safeTransferFrom(msg.sender, account, id, 1, "");
        }

        emit EventsLib.ConvertMint(to, collectionTokenId);

        return collectionTokenId;
    }

    /* ------------------------------------------------- */
    /* admin                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc ICollection
    function setExtension(address extension, bool enable, bytes calldata options) external override onlyOwner {
        // fetch extension price
        uint256 price_ = IExtension(extension).price(address(0), 0);

        // get computed price
        (uint256 computedPrice,) = _prices();

        // revert if extension returns a different price
        if (price_ != computedPrice) revert ErrorsLib.Collection_InvalidExtension();

        _setExtension(extension, enable, options);
    }
    /* ------------------------------------------------- */
    /* admin                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc ICollection
    function setExtension(address extension, bool enable, bytes calldata options) external override onlyOwner {
        // fetch extension price
        uint256 price_ = IExtension(extension).price(address(0), 0);

        // get computed price
        (uint256 computedPrice,) = _prices();

        // revert if extension returns a different price
        if (price_ != computedPrice) revert ErrorsLib.Collection_InvalidExtension();

        _setExtension(extension, enable, options);
    }
    /* ------------------------------------------------- */
    /* internal                                          */
    /* ------------------------------------------------- */

    /**
     * @notice get price for collection
     * @return price
     */
    function _prices() internal view returns (uint256, uint256[] memory) {
        MultiEditionCollectionStorage storage $$ = _multiEditionCollectionStorage();

        uint256 length = $$.itemTargets.length;
        uint256 total;
        uint256[] memory prices = new uint256[](length);

        for (uint256 i = 0; i < length; ++i) {
            uint256 price_ = IRouxEdition($$.itemTargets[i]).defaultPrice($$.itemIds[i]);
            prices[i] = price_;
            total += price_;
        }

        return (total, prices);
    }

    /**
     * @notice internal function mint collection nft
     * @param to address to mint to
     * @param referrer referrer
     * @param totalCost computed price
     * @param prices array of prices
     */
    function _mint(
        address to,
        address referrer,
        uint256 totalCost,
        uint256[] memory prices
    )
        internal
        returns (uint256)
    {
        CollectionStorage storage $ = _collectionStorage();
        MultiEditionCollectionStorage storage $$ = _multiEditionCollectionStorage();

        if (block.timestamp < $$.mintParams.mintStart) revert ErrorsLib.Collection_MintNotStarted();
        if (block.timestamp > $$.mintParams.mintEnd) revert ErrorsLib.Collection_MintEnded();

        // increment token id
        uint256 collectionTokenId = ++$.tokenIds;

        // mint token bound account
        address account = _mintTba(to, collectionTokenId, ROUX_MULTI_EDITION_COLLECTION_SALT);

        // transfer payment
        $.currency.safeTransferFrom(msg.sender, address(this), totalCost);

        // initialize rewards variables
        uint256 totalCuratorReward;
        uint256 totalReferralReward;

        // mint
        for (uint256 i = 0; i < $$.itemTargets.length; ++i) {
            address edition = $$.itemTargets[i];
            uint256 id = $$.itemIds[i];

            // get token price
            uint256 cost = prices[i];

            // compute rewards
            uint256 referralReward = referrer == address(0) ? 0 : (cost * REFERRAL_FEE) / 10_000;
            uint256 curatorReward = ((cost - referralReward) * CURATOR_FEE) / 10_000;

            // increment total rewards
            totalReferralReward += referralReward;
            totalCuratorReward += curatorReward;

            // send funds to controller
            _controller.disburse({
                edition: edition,
                id: id,
                amount: cost - referralReward - curatorReward,
                referrer: address(0)
            });

            // mint edition to token bound account
            IRouxEdition(edition).collectionMultiMint(account, id, "");
        }

        // record rewards
        if (totalReferralReward > 0) _controller.recordFunds(referrer, totalReferralReward);
        _controller.recordFunds($$.collectionFeeRecipient, totalCuratorReward);

        return collectionTokenId;
    }
}
