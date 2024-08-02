// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ICollection } from "src/interfaces/ICollection.sol";
import { ICollectionExtension } from "src/interfaces/ICollectionExtension.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IController } from "src/interfaces/IController.sol";

import { Collection } from "src/abstracts/Collection.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, CURATOR_FEE } from "src/libraries/FeesLib.sol";
import { ROUX_MULTI_EDITION_COLLECTION_SALT, MAX_MULTI_EDITION_COLLECTION_SIZE } from "src/libraries/ConstantsLib.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { ERC721 } from "solady/tokens/ERC721.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { CollectionData } from "src/types/DataTypes.sol";

/**
 * @title Multi Edition Collection
 * @custom:version 0.1
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
     * @param rouxEditionFactory roux edition factory
     * @param controller controller
     */
    constructor(
        address erc6551registry,
        address accountImplementation,
        address rouxEditionFactory,
        address controller
    )
        Collection(erc6551registry, accountImplementation, rouxEditionFactory, controller)
    { }

    /* ------------------------------------------------- */
    /* initializer                                       */
    /* ------------------------------------------------- */

    /**
     * @notice initialize collection
     * @param params encoded parameters
     */
    function initialize(bytes calldata params) external initializer {
        CollectionStorage storage $ = _collectionStorage();
        MultiEditionCollectionStorage storage $$ = _multiEditionCollectionStorage();

        // decode params
        (CollectionData.MultiEditionCreateParams memory p) =
            abi.decode(params, (CollectionData.MultiEditionCreateParams));

        // factory will transfer ownership to its caller
        _initializeOwner(msg.sender);

        // validate length
        if (p.itemTargets.length != p.itemIds.length) revert ErrorsLib.Collection_InvalidItems();

        // validate collection size
        if (p.itemIds.length > MAX_MULTI_EDITION_COLLECTION_SIZE) {
            revert ErrorsLib.Collection_InvalidCollectionSize();
        }

        for (uint256 i = 0; i < p.itemIds.length; i++) {
            // verify editions
            if (!_editionFactory.isEdition(p.itemTargets[i])) revert ErrorsLib.Collection_InvalidItems();

            // verify items
            if (!IRouxEdition(p.itemTargets[i]).multiCollectionMintEligible(p.itemIds[i], p.currency)) {
                revert ErrorsLib.Collection_InvalidItems();
            }
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
        $.curator = p.curator;
        $.uri = p.uri;
        $.currency = p.currency;
        $.gate = false;

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
        for (uint256 i = 0; i < $$.itemTargets.length; i++) {
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
        if (extension != address(0)) {
            if (!_isExtension(extension)) revert ErrorsLib.Collection_InvalidExtension();
            ICollectionExtension(extension).approveMint({ operator: msg.sender, account: to, data: data });
        } else {
            // check gate ~ if gate is enabled, must be minted via minter
            if (_collectionStorage().gate) revert ErrorsLib.Collection_GatedMint();
        }

        return _mint(to, referrer);
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

        for (uint256 i = 0; i < length; i++) {
            uint256 price_ = IRouxEdition($$.itemTargets[i]).defaultPrice($$.itemIds[i]);
            prices[i] = price_;
            total += price_;
        }

        return (total, prices);
    }

    /**
     * @notice internal function mint collection nft
     * @param to address to mint to
     */
    function _mint(address to, address referrer) internal returns (uint256) {
        CollectionStorage storage $ = _collectionStorage();
        MultiEditionCollectionStorage storage $$ = _multiEditionCollectionStorage();

        // increment token id
        uint256 collectionTokenId = ++$.tokenIds;

        // mint token bound account
        address account = _mintTba(to, collectionTokenId, ROUX_MULTI_EDITION_COLLECTION_SALT);

        // get prices
        (uint256 totalPrice, uint256[] memory prices) = _prices();

        // transfer payment
        $.currency.safeTransferFrom(msg.sender, address(this), totalPrice);

        // initialize rewards variables
        uint256 totalCuratorReward;
        uint256 totalReferralReward;

        // mint
        for (uint256 i = 0; i < $$.itemTargets.length; i++) {
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
        _controller.recordFunds(referrer, totalReferralReward);
        _controller.recordFunds($$.collectionFeeRecipient, totalCuratorReward);

        return collectionTokenId;
    }
}
