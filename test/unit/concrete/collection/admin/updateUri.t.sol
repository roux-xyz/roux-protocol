// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
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
}
