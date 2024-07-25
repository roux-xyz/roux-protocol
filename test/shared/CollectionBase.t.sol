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

/**
 * @title CollectionBase test
 */
abstract contract CollectionBase is BaseTest {
    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    uint256 constant NUM_TOKENS_IN_COLLECTION = 5;

    // users
    address user;
    address collectionAdmin;

    // single edition collection
    uint256[] tokenIds;
    uint256[] quantities;
    uint256 collectionId;
    SingleEditionCollection singleEditionCollection;

    // multi edition collection
    RouxEdition[] multiEditionItemTargets = new RouxEdition[](3);
    uint256[] multiEditionItemIds = new uint256[](3);
    MultiEditionCollection multiEditionCollection;

    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual override {
        BaseTest.setUp();

        // set agents
        user = address(users.user_0);
        collectionAdmin = address(users.creator_0);

        vm.prank(users.deployer);
        collectionFactory.setAllowlist(false);

        // create single edition collection
        (tokenIds, quantities, singleEditionCollection) =
            _createSingleEditionCollection(edition, NUM_TOKENS_IN_COLLECTION);

        collectionId = _encodeCollectionId(tokenIds);

        vm.prank(collectionAdmin);
        edition.setCollection(collectionId, address(singleEditionCollection), true);

        _approveToken(address(singleEditionCollection), user);

        // create multi edition collection
        multiEditionItemTargets[0] = _createEdition(users.creator_0);
        multiEditionItemTargets[1] = _createEdition(users.creator_1);
        multiEditionItemTargets[2] = _createEdition(users.creator_2);

        _addToken(multiEditionItemTargets[0]);
        _addToken(multiEditionItemTargets[1]);
        _addToken(multiEditionItemTargets[2]);

        multiEditionItemIds[0] = 1;
        multiEditionItemIds[1] = 1;
        multiEditionItemIds[2] = 1;

        multiEditionCollection = _createMultiEditionCollection(multiEditionItemTargets, multiEditionItemIds);

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
        returns (uint256[] memory tokenIds_, uint256[] memory quantities_, SingleEditionCollection collection_)
    {
        // 1st already created
        _addMultipleTokens(edition_, num - 1);

        tokenIds_ = new uint256[](num);
        quantities_ = new uint256[](num);

        for (uint256 i = 0; i < num; i++) {
            tokenIds_[i] = i + 1;
            quantities_[i] = 1;
        }

        // deploy collection
        collection_ = _createSingleEditionCollectionWithParams(address(edition_), tokenIds_);
    }

    /// @dev create collection with params
    function _createSingleEditionCollectionWithParams(
        address itemTarget,
        uint256[] memory multiEditionItemIds_
    )
        internal
        returns (SingleEditionCollection)
    {
        // create params
        bytes memory params = abi.encode(
            COLLECTION_NAME,
            COLLECTION_SYMBOL,
            address(collectionAdmin),
            COLLECTION_URI,
            SINGLE_EDITION_COLLECTION_PRICE,
            address(mockUSDC),
            uint40(block.timestamp),
            uint40(block.timestamp + MINT_DURATION),
            address(itemTarget),
            multiEditionItemIds_
        );

        vm.prank(collectionAdmin);
        SingleEditionCollection collectionInstance =
            SingleEditionCollection((collectionFactory.create(CollectionData.CollectionType.SingleEdition, params)));

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

    /// @dev create multi edition collection with params
    function _createMultiEditionCollection(
        RouxEdition[] memory multiEditionItemTargets_,
        uint256[] memory multiEditionItemIds_
    )
        internal
        returns (MultiEditionCollection)
    {
        // create params
        bytes memory params = abi.encode(
            COLLECTION_NAME,
            COLLECTION_SYMBOL,
            address(collectionAdmin),
            address(collectionAdmin),
            COLLECTION_URI,
            address(mockUSDC),
            uint40(block.timestamp),
            uint40(block.timestamp + MINT_DURATION),
            multiEditionItemTargets_,
            multiEditionItemIds_
        );

        vm.prank(collectionAdmin);
        MultiEditionCollection collectionInstance =
            MultiEditionCollection((collectionFactory.create(CollectionData.CollectionType.MultiEdition, params)));

        return collectionInstance;
    }
}
