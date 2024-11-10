// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { RouxEditionFactory } from "src/core/RouxEditionFactory.sol";
import { ERC6551Account } from "src/core/ERC6551Account.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { CollectionFactory } from "src/core/CollectionFactory.sol";
import { SingleEditionCollection } from "src/core/SingleEditionCollection.sol";
import { MultiEditionCollection } from "src/core/MultiEditionCollection.sol";
import { ICollection } from "src/core/interfaces/ICollection.sol";
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
        _setupAgents();
        _setupSingleEditionCollection();
        _setupMultiEditionCollection();
        _setupMockCollectionExtension();
    }

    /* -------------------------------------------- */
    /* utility functions                            */
    /* -------------------------------------------- */

    /// @dev setup agents
    function _setupAgents() internal {
        collectionAdmin = address(creator);
        curator = address(users.curator_0);

        vm.prank(users.deployer);
    }

    /// @dev setup single edition collection
    function _setupSingleEditionCollection() internal {
        _setSingleEditionCollectionParams();

        (singleEditionCollectionIds, singleEditionCollectionQuantities, singleEditionCollection) =
            _createSingleEditionCollection(edition, NUM_TOKENS_SINGLE_EDITION_COLLECTION);

        vm.prank(collectionAdmin);
        edition.setCollection(address(singleEditionCollection), true);

        _approveToken(address(singleEditionCollection), user);
    }

    /// @dev setup multi edition collection
    function _setupMultiEditionCollection() internal {
        _createMultiEditionItems();

        _setMultiEditionCollectionParams();
        multiEditionCollection = _createMultiEditionCollection(multiEditionItemTargets, multiEditionItemIds);
        _approveToken(address(multiEditionCollection), user);
    }

    /// @dev setup mock collection extension
    function _setupMockCollectionExtension() internal {
        mockCollectionExtension = new MockCollectionExtension();
    }

    /// @dev set single edition collection params
    function _setSingleEditionCollectionParams() internal {
        singleEditionCollectionParams = CollectionData.SingleEditionCreateParams({
            name: COLLECTION_NAME,
            symbol: COLLECTION_SYMBOL,
            uri: COLLECTION_URI,
            price: SINGLE_EDITION_COLLECTION_PRICE,
            mintStart: uint40(block.timestamp),
            mintEnd: uint40(block.timestamp + MINT_DURATION),
            itemTarget: address(edition),
            itemIds: singleEditionCollectionIds
        });
    }

    /// @dev create multi edition items
    function _createMultiEditionItems() internal {
        multiEditionItemTargets[0] = _createEdition(creator);
        multiEditionItemTargets[1] = _createEdition(users.creator_1);
        multiEditionItemTargets[2] = _createEdition(users.creator_2);

        (, multiEditionItemIds[0]) = _addToken(multiEditionItemTargets[0]);
        (, multiEditionItemIds[1]) = _addToken(multiEditionItemTargets[1]);
        (, multiEditionItemIds[2]) = _addToken(multiEditionItemTargets[2]);
    }

    /// @dev set multi edition collection params
    function _setMultiEditionCollectionParams() internal {
        multiEditionCollectionParams = CollectionData.MultiEditionCreateParams({
            name: COLLECTION_NAME,
            symbol: COLLECTION_SYMBOL,
            collectionFeeRecipient: address(curator),
            uri: COLLECTION_URI,
            mintStart: uint40(block.timestamp),
            mintEnd: uint40(block.timestamp + MINT_DURATION),
            itemTargets: _convertToAddressArray(multiEditionItemTargets),
            itemIds: multiEditionItemIds
        });
    }

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
        SingleEditionCollection collectionInstance = SingleEditionCollection(collectionFactory.createSingle(params));

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
        MultiEditionCollection collectionInstance = MultiEditionCollection(collectionFactory.createMulti(params));

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
