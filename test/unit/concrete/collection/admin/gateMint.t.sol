// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { CollectionData, EditionData } from "src/types/DataTypes.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract GateMint_Collection_Unit_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual override {
        CollectionBase.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when not owner
    function test__RevertWhen_GateMint_NotOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        singleEditionCollection.gateMint(true);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully gates mint
    function test__GateMint() external {
        vm.prank(collectionAdmin);
        singleEditionCollection.gateMint(true);

        assertTrue(singleEditionCollection.isGated());
    }

    /// @dev successfully ungates mint
    function test__UngateMint() external {
        vm.prank(collectionAdmin);
        singleEditionCollection.gateMint(true);

        assertTrue(singleEditionCollection.isGated());

        vm.prank(collectionAdmin);
        singleEditionCollection.gateMint(false);

        assertFalse(singleEditionCollection.isGated());
    }
}
