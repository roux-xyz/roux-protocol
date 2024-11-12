// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { SingleEditionCollection } from "src/core/SingleEditionCollection.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { CollectionData, EditionData } from "src/types/DataTypes.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { MAX_SINGLE_EDITION_COLLECTION_SIZE } from "src/libraries/ConstantsLib.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

contract Initialize_SingleEditionCollection_Unit_Concrete_Test is CollectionBase {
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
        singleEditionCollection.initialize(singleEditionCollectionParams);
    }

    /// @dev reverts when collection size is too large
    function test__RevertWhen_CollectionSizeIsTooLarge() external {
        // new array
        uint256[] memory newItemIds = new uint256[](MAX_SINGLE_EDITION_COLLECTION_SIZE + 1);

        for (uint256 i = 0; i < MAX_SINGLE_EDITION_COLLECTION_SIZE + 1; i++) {
            newItemIds[i] = i + 1;
        }

        // encode params
        CollectionData.SingleEditionCreateParams memory params = singleEditionCollectionParams;
        params.itemIds = newItemIds;

        vm.prank(collectionAdmin);
        vm.expectRevert(Create2.Create2FailedDeployment.selector);
        SingleEditionCollection(collectionFactory.createSingle(params));
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully initializes collection
    function test__Initialize() external {
        // create new edition
        address edition_ = address(_createEdition(creator));

        // add 3 tokens
        _addMultipleTokens(RouxEdition(edition_), 3);

        // create array of item ids
        uint256[] memory itemIds = new uint256[](3);
        itemIds[0] = 1;
        itemIds[1] = 2;
        itemIds[2] = 3;

        // copy params
        CollectionData.SingleEditionCreateParams memory params = singleEditionCollectionParams;

        // modify params
        params.price = SINGLE_EDITION_COLLECTION_PRICE + 888;
        params.itemTarget = edition_;
        params.itemIds = itemIds;

        // create collection
        vm.prank(collectionAdmin);
        SingleEditionCollection collectionInstance = SingleEditionCollection(collectionFactory.createSingle(params));

        // assert collection state
        assertEq(collectionInstance.name(), COLLECTION_NAME);
        assertEq(collectionInstance.symbol(), COLLECTION_SYMBOL);
        assertEq(collectionInstance.tokenURI(1), COLLECTION_URI);
        assertEq(collectionInstance.price(), SINGLE_EDITION_COLLECTION_PRICE + 888);
        assertEq(collectionInstance.currency(), address(mockUSDC));
        assertEq(collectionInstance.totalSupply(), 0);
        assertEq(collectionInstance.isRegisteredExtension(address(mockExtension)), false);
        assertEq(collectionInstance.curator(), address(collectionAdmin));

        (address[] memory itemTargets, uint256[] memory itemIds_) = collectionInstance.collection();
        assertEq(itemTargets.length, 3);
        assertEq(itemTargets[0], edition_);
        assertEq(itemIds_.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(itemIds_[i], itemIds[i]);
        }
    }
}
