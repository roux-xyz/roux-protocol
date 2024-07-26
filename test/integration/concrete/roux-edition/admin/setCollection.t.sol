// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract SetCollection_RouxEdition_Integration_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    function setUp() public override {
        CollectionBase.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev only owner can set collection
    function test__RevertWhen_OnlyOwner_SetCollection() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.setCollection(collectionId, address(singleEditionCollection), true);
    }

    /// @dev reverts when setting invalid collection id - zero
    function test__RevertWhen_SetInvalidCollectionId_Zero() external {
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidParams.selector);
        edition.setCollection(0, address(singleEditionCollection), true);
    }

    /// @dev reverts when setting invalid collection - zero address
    function test__RevertWhen_SetInvalidCollection_ZeroAddress() external {
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidCollection.selector);
        edition.setCollection(collectionId, address(0), true);
    }

    /// @dev reverts when setting invalid collection - unsupported interface
    function test__RevertWhen_SetInvalidCollection_UnsupportedInterface() external {
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidCollection.selector);
        edition.setCollection(collectionId, address(edition), true);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev set collection
    function test__SetCollection() external useEditionAdmin(edition) {
        vm.expectEmit({ emitter: address(edition) });
        emit EventsLib.CollectionSet(address(singleEditionCollection), collectionId, true);

        uint256 collectionId_ = edition.setCollection(collectionId, address(singleEditionCollection), true);

        assertTrue(edition.isCollection(collectionId, address(singleEditionCollection)));
        assertEq(collectionId_, collectionId);
    }

    /// @dev set collection - disable
    function test__SetCollection_Disable() external useEditionAdmin(edition) {
        edition.setCollection(collectionId, address(singleEditionCollection), true);

        assertTrue(edition.isCollection(collectionId, address(singleEditionCollection)));

        vm.expectEmit({ emitter: address(edition) });
        emit EventsLib.CollectionSet(address(singleEditionCollection), collectionId, false);

        edition.setCollection(collectionId, address(singleEditionCollection), false);

        assertFalse(edition.isCollection(collectionId, address(singleEditionCollection)));
    }
}
