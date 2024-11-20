// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { SingleEditionCollection } from "src/core/SingleEditionCollection.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract SetCollection_RouxEditionCoCreate_Integration_Concrete_Test is CollectionBase {
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
    function test__RevertWhen_SetCollection() external {
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEditionCoCreate_NotAllowed.selector);
        coCreateEdition.setCollection(address(singleEditionCollection), true);
    }
}
