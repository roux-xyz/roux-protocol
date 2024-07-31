// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { RouxEditionFactory } from "src/RouxEditionFactory.sol";
import { ERC6551Account } from "src/ERC6551Account.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { CollectionFactory } from "src/CollectionFactory.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { MultiEditionCollection } from "src/MultiEditionCollection.sol";
import { ICollection } from "src/interfaces/ICollection.sol";
import { Events } from "test/utils/Events.sol";
import { Defaults } from "test/utils/Defaults.sol";
import { EditionData, CollectionData } from "src/types/DataTypes.sol";
import { MockUSDC } from "test/mocks/MockUSDC.sol";
import { MockCollectionExtension } from "test/mocks/MockCollectionExtension.sol";

/**
 * @title CollectionBase test
 */
abstract contract CollectionBase is BaseTest {
    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    uint256 constant NUM_TOKENS_SINGLE_EDITION_COLLECTION = 5;

    // users
    address collectionAdmin;
    address curator;

    // single edition collection
    uint256[] singleEditionCollectionIds;
    uint256[] singleEditionCollectionQuantities;
    uint256 collectionId;
    SingleEditionCollection singleEditionCollection;

    // single edition collection create params
    CollectionData.SingleEditionCreateParams singleEditionCollectionParams;

    // multi edition collection
    RouxEdition[] multiEditionItemTargets = new RouxEdition[](3);
    uint256[] multiEditionItemIds = new uint256[](3);
    MultiEditionCollection multiEditionCollection;

    // multi edition collection create params
    CollectionData.MultiEditionCreateParams multiEditionCollectionParams;

    // mock collection extension
    MockCollectionExtension mockCollectionExtension;

    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual override {
        BaseTest.setUp();

        // set agents
        collectionAdmin = address(creator);
        curator = address(users.curator_0);

        vm.prank(users.deployer);
        collectionFactory.setAllowlist(false);

        // set single edition collection params
        singleEditionCollectionParams = CollectionData.SingleEditionCreateParams({
            name: COLLECTION_NAME,
            symbol: COLLECTION_SYMBOL,
            curator: address(collectionAdmin),
            uri: COLLECTION_URI,
            price: SINGLE_EDITION_COLLECTION_PRICE,
            currency: address(mockUSDC),
            mintStart: uint40(block.timestamp),
            mintEnd: uint40(block.timestamp + MINT_DURATION),
            itemTarget: address(edition),
            itemIds: singleEditionCollectionIds
        });

        // create single edition collection
        (singleEditionCollectionIds, singleEditionCollectionQuantities, singleEditionCollection) =
            _createSingleEditionCollection(edition, NUM_TOKENS_SINGLE_EDITION_COLLECTION);

        collectionId = _encodeCollectionId(singleEditionCollectionIds);

        vm.prank(collectionAdmin);
        edition.setCollection(collectionId, address(singleEditionCollection), true);

        _approveToken(address(singleEditionCollection), user);

        // create multi edition collection
        multiEditionItemTargets[0] = _createEdition(creator);
        multiEditionItemTargets[1] = _createEdition(users.creator_1);
        multiEditionItemTargets[2] = _createEdition(users.creator_2);

        _addToken(multiEditionItemTargets[0]);
        _addToken(multiEditionItemTargets[1]);
        _addToken(multiEditionItemTargets[2]);

        multiEditionItemIds[0] = 1;
        multiEditionItemIds[1] = 1;
        multiEditionItemIds[2] = 1;

        // create multi edition collection params
        multiEditionCollectionParams = CollectionData.MultiEditionCreateParams({
            name: COLLECTION_NAME,
            symbol: COLLECTION_SYMBOL,
            curator: address(curator),
            collectionFeeRecipient: address(curator),
            uri: COLLECTION_URI,
            currency: address(mockUSDC),
            mintStart: uint40(block.timestamp),
            mintEnd: uint40(block.timestamp + MINT_DURATION),
            itemTargets: _convertToAddressArray(multiEditionItemTargets),
            itemIds: multiEditionItemIds
        });

        multiEditionCollection = _createMultiEditionCollection(multiEditionItemTargets, multiEditionItemIds);

        mockCollectionExtension = new MockCollectionExtension();

        _approveToken(address(multiEditionCollection), user);
    }

    /* -------------------------------------------- */
    /* utility functions                            */
    /* -------------------------------------------- */

    /// @dev create single edition collection
    function _createSingleEditionCollection(
        RouxEdition edition_,
        uint256 num
    )
        internal
        returns (
            uint256[] memory singleEditionCollectionIds_,
            uint256[] memory quantities_,
            SingleEditionCollection collection_
        )
    {
        // 1st already created
        _addMultipleTokens(edition_, num - 1);

        singleEditionCollectionIds_ = new uint256[](num);
        quantities_ = new uint256[](num);

        for (uint256 i = 0; i < num; i++) {
            singleEditionCollectionIds_[i] = i + 1;
            quantities_[i] = 1;
        }

        // deploy collection
        collection_ = _createSingleEditionCollectionWithParams(address(edition_), singleEditionCollectionIds_);
    }

    /// @dev create single edition collection with params
    function _createSingleEditionCollectionWithParams(
        address itemTarget,
        uint256[] memory itemIds
    )
        internal
        returns (SingleEditionCollection)
    {
        CollectionData.SingleEditionCreateParams memory params = singleEditionCollectionParams;
        params.itemTarget = itemTarget;
        params.itemIds = itemIds;

        vm.prank(collectionAdmin);
        SingleEditionCollection collectionInstance = SingleEditionCollection(
            collectionFactory.create(CollectionData.CollectionType.SingleEdition, abi.encode(params))
        );

        return collectionInstance;
    }

    /// @dev create multi edition collection with params
    function _createMultiEditionCollection(
        RouxEdition[] memory itemTargets,
        uint256[] memory itemIds
    )
        internal
        returns (MultiEditionCollection)
    {
        CollectionData.MultiEditionCreateParams memory params = multiEditionCollectionParams;
        params.itemTargets = _convertToAddressArray(itemTargets);
        params.itemIds = itemIds;

        vm.prank(curator);
        MultiEditionCollection collectionInstance = MultiEditionCollection(
            collectionFactory.create(CollectionData.CollectionType.MultiEdition, abi.encode(params))
        );

        return collectionInstance;
    }

    /// @dev encode collection id from array of token ids
    function _encodeCollectionId(uint256[] memory ids) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(ids)));
    }

    /// @dev get erc6551 account - single edition
    function _getERC6551AccountSingleEdition(address collection, uint256 tokenId) internal view returns (address) {
        return erc6551Registry.account(
            address(accountImpl),
            keccak256("ROUX_SINGLE_EDITION_COLLECTION"),
            block.chainid,
            address(collection),
            tokenId
        );
    }

    /// @dev get erc6551 account - multi edition
    function _getERC6551AccountMultiEdition(address collection, uint256 tokenId) internal view returns (address) {
        return erc6551Registry.account(
            address(accountImpl),
            keccak256("ROUX_MULTI_EDITION_COLLECTION"),
            block.chainid,
            address(collection),
            tokenId
        );
    }

    /// @dev convert RouxEdition array to address array
    function _convertToAddressArray(RouxEdition[] memory editions) internal pure returns (address[] memory) {
        address[] memory addresses = new address[](editions.length);
        for (uint256 i = 0; i < editions.length; i++) {
            addresses[i] = address(editions[i]);
        }
        return addresses;
    }
}
