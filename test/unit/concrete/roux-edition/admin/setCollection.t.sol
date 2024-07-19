// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";

contract SetCollection_RouxEdition_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    uint256[] tokenIds;
    uint256[] quantities;
    uint256 collectionId;
    SingleEditionCollection collection;

    function setUp() public override {
        BaseTest.setUp();

        // create collection
        (tokenIds, quantities, collection) = _createSingleEditionCollection(edition, 5);

        // encode collection id
        collectionId = uint256(keccak256(abi.encode(tokenIds)));
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev only owner can set collection
    function test__RevertWhen_OnlyOwner_SetCollection() external {
        vm.prank(users.user_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.setCollection(tokenIds, address(collection), true);
    }

    function test__RevertWhen_SetInvalidCollection_ZeroAddress() external {
        vm.prank(users.creator_0);
        vm.expectRevert(IRouxEdition.InvalidCollection.selector);
        edition.setCollection(tokenIds, address(0), true);
    }

    function test__RevertWhen_SetInvalidCollection_UnsupportedInterface() external {
        vm.prank(users.creator_0);
        vm.expectRevert(IRouxEdition.InvalidCollection.selector);
        edition.setCollection(tokenIds, address(edition), true);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev set collection
    function test__SetCollection() external {
        // expect emit
        vm.expectEmit({ emitter: address(edition) });
        emit CollectionSet(address(collection), collectionId, true);

        // set collection
        vm.prank(users.creator_0);
        uint256 collectionId_ = edition.setCollection(tokenIds, address(collection), true);

        assertTrue(edition.isCollection(collectionId, address(collection)));
        assertEq(collectionId_, collectionId);
    }

    /// @dev set collection - disable
    function test__SetCollection_Disable() external {
        // set collection
        vm.prank(users.creator_0);
        edition.setCollection(tokenIds, address(collection), true);

        assertTrue(edition.isCollection(collectionId, address(collection)));

        // expect emit
        vm.expectEmit({ emitter: address(edition) });
        emit CollectionSet(address(collection), collectionId, false);

        // set collection
        vm.prank(users.creator_0);
        edition.setCollection(tokenIds, address(collection), false);

        assertFalse(edition.isCollection(collectionId, address(collection)));
    }
}
