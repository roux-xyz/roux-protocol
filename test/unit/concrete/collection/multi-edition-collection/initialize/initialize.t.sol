// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { MultiEditionCollection } from "src/core/MultiEditionCollection.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { CollectionData, EditionData } from "src/types/DataTypes.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { MAX_MULTI_EDITION_COLLECTION_SIZE } from "src/libraries/ConstantsLib.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

contract Initialize_MultiEditionCollection_Unit_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual override {
        CollectionBase.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when already initialized
    function test__RevertWhen_AlreadyInitialized() external {
        // encode params
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        multiEditionCollection.initialize(multiEditionCollectionParams);
    }

    /// @dev reverts when collection size is too large
    function test__RevertWhen_CollectionSizeIsTooLarge() external {
        // new array
        address[] memory newItemTargets = new address[](MAX_MULTI_EDITION_COLLECTION_SIZE + 1);
        uint256[] memory newItemIds = new uint256[](MAX_MULTI_EDITION_COLLECTION_SIZE + 1);

        for (uint256 i = 0; i < MAX_MULTI_EDITION_COLLECTION_SIZE + 1; i++) {
            newItemTargets[i] = address(edition);
            newItemIds[i] = i + 1;
        }

        // encode params
        CollectionData.MultiEditionCreateParams memory params = multiEditionCollectionParams;
        params.itemTargets = newItemTargets;
        params.itemIds = newItemIds;

        vm.prank(collectionAdmin);
        vm.expectRevert(Create2.Create2FailedDeployment.selector);
        MultiEditionCollection(collectionFactory.createMulti(params));
    }

    /// @dev reverts when item targets and item ids are not the same length
    function test__RevertWhen_ItemTargetsAndItemIdsAreNotTheSameLength() external {
        // new array
        address[] memory newItemTargets = new address[](1);
        uint256[] memory newItemIds = new uint256[](2);

        newItemTargets[0] = address(edition);
        newItemIds[0] = 1;
        newItemIds[1] = 2;

        // encode params
        CollectionData.MultiEditionCreateParams memory params = multiEditionCollectionParams;
        params.itemTargets = newItemTargets;
        params.itemIds = newItemIds;

        vm.prank(collectionAdmin);
        vm.expectRevert(Create2.Create2FailedDeployment.selector);
        MultiEditionCollection(collectionFactory.createMulti(params));
    }

    /// @dev reverts when one of the items is gated
    function test__RevertWhen_GatedItem() external {
        // create edition instance
        RouxEdition edition_ = _createEdition(creator);

        // modify edition params to include gate
        EditionData.AddParams memory addParams = defaultAddParams;
        addParams.gate = true;

        // add token
        vm.prank(creator);
        uint256 tokenId_ = edition_.add(addParams);

        // create collection
        address[] memory itemTargets = new address[](2);
        itemTargets[0] = address(edition);
        itemTargets[1] = address(edition_);

        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = 1;
        itemIds[1] = tokenId_;

        // create array of item targets
        CollectionData.MultiEditionCreateParams memory params = multiEditionCollectionParams;
        params.itemTargets = itemTargets;
        params.itemIds = itemIds;

        vm.prank(collectionAdmin);
        vm.expectRevert(Create2.Create2FailedDeployment.selector);
        MultiEditionCollection(collectionFactory.createMulti(params));
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully initializes collection
    function test__Initialize() external {
        // create new editions
        address edition_ = address(_createEdition(creator));
        address edition2_ = address(_createEdition(creator));

        // add 3 tokens
        _addMultipleTokens(RouxEdition(edition_), 3);

        // add 5 tokens
        _addMultipleTokens(RouxEdition(edition2_), 5);

        // create array of item targets
        address[] memory itemTargets = new address[](8);
        itemTargets[0] = address(edition_);
        itemTargets[1] = address(edition_);
        itemTargets[2] = address(edition_);
        itemTargets[3] = address(edition2_);
        itemTargets[4] = address(edition2_);
        itemTargets[5] = address(edition2_);
        itemTargets[6] = address(edition2_);
        itemTargets[7] = address(edition2_);

        // create array of item ids
        uint256[] memory itemIds = new uint256[](8);
        itemIds[0] = 1;
        itemIds[1] = 2;
        itemIds[2] = 3;
        itemIds[3] = 1;
        itemIds[4] = 2;
        itemIds[5] = 3;
        itemIds[6] = 4;
        itemIds[7] = 5;

        // copy params
        CollectionData.MultiEditionCreateParams memory params = multiEditionCollectionParams;

        // modify params
        params.itemTargets = itemTargets;
        params.itemIds = itemIds;

        // create collection
        vm.prank(curator);
        MultiEditionCollection collectionInstance = MultiEditionCollection(collectionFactory.createMulti(params));

        // assert collection state
        assertEq(collectionInstance.name(), COLLECTION_NAME);
        assertEq(collectionInstance.symbol(), COLLECTION_SYMBOL);
        assertEq(collectionInstance.tokenURI(1), COLLECTION_URI);
        assertEq(collectionInstance.price(), TOKEN_PRICE * 8);
        assertEq(collectionInstance.currency(), address(mockUSDC));
        assertEq(collectionInstance.totalSupply(), 0);
        assertEq(collectionInstance.isRegisteredExtension(address(mockExtension)), false);
        assertEq(collectionInstance.curator(), address(curator));

        (address[] memory itemTargets_, uint256[] memory itemIds_) = collectionInstance.collection();
        assertEq(itemTargets_.length, 8);
        assertEq(itemIds_.length, 8);
        assertEq(itemTargets_[0], edition_);
        assertEq(itemTargets_[1], edition_);
        assertEq(itemTargets_[2], edition_);
        assertEq(itemTargets_[3], edition2_);
        assertEq(itemTargets_[4], edition2_);
        assertEq(itemTargets_[5], edition2_);
        assertEq(itemTargets_[6], edition2_);
        assertEq(itemTargets_[7], edition2_);
        assertEq(itemIds_[0], 1);
        assertEq(itemIds_[1], 2);
        assertEq(itemIds_[2], 3);
        assertEq(itemIds_[3], 1);
        assertEq(itemIds_[4], 2);
        assertEq(itemIds_[5], 3);
        assertEq(itemIds_[6], 4);
        assertEq(itemIds_[7], 5);
    }

    /// @dev successfully initializes collection
    function test__Initialize_MixedWithCommunity() external {
        // create new editions
        address edition_ = address(_createEdition(creator));
        address edition2_ = address(_createEdition(creator));
        address communityEdition_ = address(_createCommunityEdition(creator));

        // add 3 tokens
        _addMultipleTokens(RouxEdition(edition_), 3);

        // add 5 tokens
        _addMultipleTokens(RouxEdition(edition2_), 5);

        // add 2 tokens
        _addMultipleTokens(RouxEdition(communityEdition_), 1);

        // create array of item targets
        address[] memory itemTargets = new address[](9);
        itemTargets[0] = address(edition_);
        itemTargets[1] = address(edition_);
        itemTargets[2] = address(edition_);
        itemTargets[3] = address(edition2_);
        itemTargets[4] = address(edition2_);
        itemTargets[5] = address(edition2_);
        itemTargets[6] = address(edition2_);
        itemTargets[7] = address(edition2_);
        itemTargets[8] = address(communityEdition_);

        // create array of item ids
        uint256[] memory itemIds = new uint256[](9);
        itemIds[0] = 1;
        itemIds[1] = 2;
        itemIds[2] = 3;
        itemIds[3] = 1;
        itemIds[4] = 2;
        itemIds[5] = 3;
        itemIds[6] = 4;
        itemIds[7] = 5;
        itemIds[8] = 1;

        // copy params
        CollectionData.MultiEditionCreateParams memory params = multiEditionCollectionParams;

        // modify params
        params.itemTargets = itemTargets;
        params.itemIds = itemIds;

        // create collection
        vm.prank(curator);
        MultiEditionCollection collectionInstance = MultiEditionCollection(collectionFactory.createMulti(params));

        // assert collection state
        assertEq(collectionInstance.name(), COLLECTION_NAME);
        assertEq(collectionInstance.symbol(), COLLECTION_SYMBOL);
        assertEq(collectionInstance.tokenURI(1), COLLECTION_URI);
        assertEq(collectionInstance.price(), TOKEN_PRICE * 9);
        assertEq(collectionInstance.currency(), address(mockUSDC));
        assertEq(collectionInstance.totalSupply(), 0);
        assertEq(collectionInstance.isRegisteredExtension(address(mockExtension)), false);
        assertEq(collectionInstance.curator(), address(curator));

        (address[] memory itemTargets_, uint256[] memory itemIds_) = collectionInstance.collection();
        assertEq(itemTargets_.length, 9);
        assertEq(itemIds_.length, 9);
        assertEq(itemTargets_[0], edition_);
        assertEq(itemTargets_[1], edition_);
        assertEq(itemTargets_[2], edition_);
        assertEq(itemTargets_[3], edition2_);
        assertEq(itemTargets_[4], edition2_);
        assertEq(itemTargets_[5], edition2_);
        assertEq(itemTargets_[6], edition2_);
        assertEq(itemTargets_[7], edition2_);
        assertEq(itemTargets_[8], communityEdition_);
        assertEq(itemIds_[0], 1);
        assertEq(itemIds_[1], 2);
        assertEq(itemIds_[2], 3);
        assertEq(itemIds_[3], 1);
        assertEq(itemIds_[4], 2);
        assertEq(itemIds_[5], 3);
        assertEq(itemIds_[6], 4);
        assertEq(itemIds_[7], 5);
        assertEq(itemIds_[8], 1);
    }
}
