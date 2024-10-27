// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ICollection } from "src/interfaces/ICollection.sol";
import { IExtension } from "src/interfaces/IExtension.sol";
import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IController } from "src/interfaces/IController.sol";
import { Collection } from "src/abstracts/Collection.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { CollectionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { ROUX_SINGLE_EDITION_COLLECTION_SALT, MAX_SINGLE_EDITION_COLLECTION_SIZE } from "src/libraries/ConstantsLib.sol";
import { REFERRAL_FEE } from "src/libraries/FeesLib.sol";

/**
 * @title single edition collection
 * @author roux
 * @custom:version 1.0
 * @custom:security-contact mp@roux.app
 */
contract SingleEditionCollection is Collection {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using LibBitmap for LibBitmap.Bitmap;

    /* ------------------------------------------------- */
    /* constants                                         */
    /* ------------------------------------------------- */

    /**
     * @notice SingleEditionCollection storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("singleEditionCollection.singleEditionCollectionStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant SINGLE_EDITION_COLLECTION_STORAGE_SLOT =
        0xa6e0118951a25969bd3c1390bebbde8eb1379a4bbd50f1af4df5dda29b004500;

    /* ------------------------------------------------- */
    /* structures                                        */
    /* ------------------------------------------------- */

    /**
     * @notice Collection storage
     * @custom:storage-location erc7201:singleEditionCollection.singleEditionCollectionStorage
     * @param itemTarget target edition address
     * @param itemIds array of item IDs in the collection
     * @param mintParams mint parameters
     */
    struct SingleEditionCollectionStorage {
        address itemTarget;
        uint256[] itemIds;
        CollectionData.SingleEditionMintParams mintParams;
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
     *
     * @dev single edition collections creation is unvalidated because the collection must be
     *      registered by the underlying edition via `setCollection` before a token can be minted.
     *      edition owners should not register malicious or invalid collections.
     */
    function initialize(CollectionData.SingleEditionCreateParams calldata p) external initializer {
        CollectionStorage storage $ = _collectionStorage();
        SingleEditionCollectionStorage storage $$ = _singleEditionCollectionStorage();

        // factory will transfer ownership to its caller
        _initializeOwner(msg.sender);

        // set mintParams
        $$.mintParams =
            CollectionData.SingleEditionMintParams({ price: p.price, mintStart: p.mintStart, mintEnd: p.mintEnd });

        // validate collection size
        if (p.itemIds.length > MAX_SINGLE_EDITION_COLLECTION_SIZE) {
            revert ErrorsLib.Collection_InvalidCollectionSize();
        }

        // set items
        $$.itemTarget = p.itemTarget;
        $$.itemIds = p.itemIds;

        // set collection state variables
        $.name = p.name;
        $.symbol = p.symbol;
        $.uri = p.uri;
        $.currency = IController(_controller).currency();

        // approve controller to spend funds
        IERC20($.currency).approve(address(_controller), type(uint256).max);
    }

    /* ------------------------------------------------- */
    /* storage                                           */
    /* ------------------------------------------------- */

    /**
     * @notice SingleEditionCollection storage
     * @return $$ SingleEditionCollection storage location
     */
    function _singleEditionCollectionStorage() internal pure returns (SingleEditionCollectionStorage storage $$) {
        assembly {
            $$.slot := SINGLE_EDITION_COLLECTION_STORAGE_SLOT
        }
    }

    /* ------------------------------------------------- */
    /* view                                              */
    /* ------------------------------------------------- */

    /// @inheritdoc ICollection
    function price() external view override returns (uint256) {
        return _singleEditionCollectionStorage().mintParams.price;
    }

    /// @inheritdoc ICollection
    function collection() external view override returns (address[] memory, uint256[] memory) {
        SingleEditionCollectionStorage storage $$ = _singleEditionCollectionStorage();

        // cache item ids
        uint256[] memory itemIds = $$.itemIds;

        // collection expects equal length arrays of addresses and ids
        address[] memory itemTargets = new address[](itemIds.length);
        for (uint256 i = 0; i < itemIds.length; ++i) {
            itemTargets[i] = $$.itemTarget;
        }

        return (itemTargets, itemIds);
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
        uint256 price_;
        if (extension != address(0)) {
            if (!_isRegisteredExtension(extension)) revert ErrorsLib.Collection_InvalidExtension();
            price_ =
                IExtension(extension).approveMint({ id: 0, quantity: 1, operator: msg.sender, account: to, data: data });
        } else {
            // check gate ~ if gate is enabled, must be minted via minter
            if (_collectionStorage().gate) revert ErrorsLib.Collection_GatedMint();

            // set cost ~ only single edition collections have a price set in storage
            price_ = _singleEditionCollectionStorage().mintParams.price;
        }

        return _mint(to, referrer, price_);
    }

    /**
     * @notice admin mint
     * @param to address to mint to
     *
     * @dev singleEdition collection owner is owner of the underlying edition as well
     */
    function adminMint(address to) external onlyOwner {
        _mint(to, address(0), 0);
    }

    /* ------------------------------------------------- */
    /* admin                                             */
    /* ------------------------------------------------- */

    /**
     * @notice update collection price
     * @param newPrice new price
     */
    function updateCollectionPrice(uint256 newPrice) external onlyOwner {
        _singleEditionCollectionStorage().mintParams.price = newPrice.toUint128();

        emit EventsLib.CollectionPriceUpdated(address(this), newPrice);
    }

    /// @inheritdoc ICollection
    function setExtension(address extension, bool enable, bytes calldata options) external override onlyOwner {
        _setExtension(extension, enable, options);
    }

    /* ------------------------------------------------- */
    /* internal                                          */
    /* ------------------------------------------------- */

    /**
     * @notice internal function mint collection nft
     * @param to address to mint to
     * @param referrer referrer
     * @param cost cost
     * @return collection token id
     */
    function _mint(address to, address referrer, uint256 cost) internal returns (uint256) {
        CollectionStorage storage $ = _collectionStorage();
        SingleEditionCollectionStorage storage $$ = _singleEditionCollectionStorage();

        if (block.timestamp < $$.mintParams.mintStart) revert ErrorsLib.Collection_MintNotStarted();
        if (block.timestamp > $$.mintParams.mintEnd) revert ErrorsLib.Collection_MintEnded();

        // increment token id
        uint256 collectionTokenId = ++$.tokenIds;

        // mint tba
        address account = _mintTba(to, collectionTokenId, ROUX_SINGLE_EDITION_COLLECTION_SALT);

        // transfer payment
        $.currency.safeTransferFrom(msg.sender, address(this), cost);

        // cache item data
        uint256[] memory itemIds = $$.itemIds;
        address itemTarget = $$.itemTarget;

        // disburse funds
        if (cost > 0) {
            uint256 derivedPrice = cost / itemIds.length;
            uint256 currentValue = cost;
            for (uint256 i = 0; i < itemIds.length; ++i) {
                // cache id
                uint256 id = itemIds[i];

                // calculate funds disbursement
                uint256 allocatedValue = currentValue < derivedPrice ? currentValue : derivedPrice;
                currentValue -= allocatedValue;

                // send funds to controller
                if (allocatedValue > 0) {
                    _controller.disburse({ edition: itemTarget, id: id, amount: allocatedValue, referrer: referrer });
                }
            }
        }

        // mint to collection nft token bound account
        IRouxEdition(itemTarget).collectionSingleMint(account, itemIds, "");

        return collectionTokenId;
    }
}
