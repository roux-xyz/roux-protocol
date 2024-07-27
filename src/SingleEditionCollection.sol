// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ICollection } from "src/interfaces/ICollection.sol";
import { ICollectionExtension } from "src/interfaces/ICollectionExtension.sol";
import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";

import { Collection } from "src/abstracts/Collection.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { ROUX_SINGLE_EDITION_COLLECTION_SALT } from "src/libraries/ConstantsLib.sol";
import { REFERRAL_FEE } from "src/libraries/FeesLib.sol";

import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { CollectionData } from "src/types/DataTypes.sol";

/**
 * @title Single Edition Collection
 * @custom:version 0.1
 */
contract SingleEditionCollection is Collection {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

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
     * @param mintParams mint parameters
     */
    struct SingleEditionCollectionStorage {
        CollectionData.SingleEditionMintParams mintParams;
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
     *
     * @dev single edition collections creation is unvalidated because the collection must be
     *      registered by the underlying edition via `setCollection` before a token can be minted
     */
    function initialize(bytes calldata params) external initializer {
        CollectionStorage storage $ = _collectionStorage();

        // factory will transfer ownership to its caller
        _initializeOwner(msg.sender);

        // decode params
        (CollectionData.SingleEditionCreateParams memory p) =
            abi.decode(params, (CollectionData.SingleEditionCreateParams));

        // set mintParams
        _singleEditionCollectionStorage().mintParams =
            CollectionData.SingleEditionMintParams({ price: p.price, mintStart: p.mintStart, mintEnd: p.mintEnd });

        // set item target
        $.itemTargets = new address[](1);
        $.itemTargets[0] = p.itemTarget;

        // set collection state vars
        $.name = p.name;
        $.symbol = p.symbol;
        $.curator = p.curator;
        $.uri = p.uri;
        $.currency = p.currency;
        $.itemIds = p.itemIds;
        $.gate = false;

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
        CollectionStorage storage $ = _collectionStorage();

        uint128 cost;
        if (extension != address(0)) {
            if (!$.extensions[extension]) revert ErrorsLib.Collection_InvalidExtension();
            cost = ICollectionExtension(extension).approveMint({ operator: msg.sender, account: to, data: data });
        } else {
            // check gate ~ if gate is enabled, must be minted via minter
            if ($.gate) revert ErrorsLib.Collection_GatedMint();

            // set cost ~ only single edition collections have a price set in storage
            cost = _singleEditionCollectionStorage().mintParams.price;
        }

        return _mint(to, referrer, cost);
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

        // increment token id
        uint256 collectionTokenId = ++$.tokenIds;

        // mint collection nft
        _mint(to, collectionTokenId);

        // erc 6551
        address account = _erc6551Registry.createAccount(
            _accountImplementation, ROUX_SINGLE_EDITION_COLLECTION_SALT, block.chainid, address(this), collectionTokenId
        );

        // transfer payment
        $.currency.safeTransferFrom(msg.sender, address(this), cost);

        // calculate referral reward
        uint256 referralReward = (referrer != address(0)) ? (cost * REFERRAL_FEE) / 10_000 : 0;

        // approve edition to spend funds
        IERC20($.currency).approve(address($.itemTargets[0]), cost);

        // mint to collection nft token bound account
        IRouxEdition($.itemTargets[0]).collectionSingleMint(account, $.itemIds, cost - referralReward, "");

        // record referral reward
        if (referralReward > 0) _controller.recordFunds(referrer, referralReward);

        return collectionTokenId;
    }
}
