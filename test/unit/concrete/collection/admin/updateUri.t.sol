// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { SingleEditionCollection } from "src/core/SingleEditionCollection.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { CollectionData, EditionData } from "src/types/DataTypes.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract UpdateUri_Collection_Unit_Concrete_Test is CollectionBase {
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
    function test__RevertWhen_UpdateUri_NotOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        singleEditionCollection.updateUri("https://new.com");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates uri
    function test__UpdateUri() external {
        string memory originalUri = singleEditionCollection.tokenURI(0);
        string memory newUri = "https://new.com";

        vm.expectEmit({ emitter: address(singleEditionCollection) });
        emit EventsLib.UriUpdated(newUri);

        vm.prank(collectionAdmin);
        singleEditionCollection.updateUri(newUri);

        assertEq(singleEditionCollection.tokenURI(1), newUri);
        assertNotEq(singleEditionCollection.tokenURI(1), originalUri);
    }

    function test__UpdateUri_AsRoleSetter() external {
        string memory originalUri = singleEditionCollection.tokenURI(0);
        string memory newUri = "https://new.com";

        // Grant URI_SETTER_ROLE to user
        vm.prank(collectionAdmin);
        singleEditionCollection.grantRoles(user, 1);

        vm.expectEmit({ emitter: address(singleEditionCollection) });
        emit EventsLib.UriUpdated(newUri);

        // Update URI as role holder
        vm.prank(user);
        singleEditionCollection.updateUri(newUri);

        assertEq(singleEditionCollection.tokenURI(1), newUri);
        assertNotEq(singleEditionCollection.tokenURI(1), originalUri);
    }
}
