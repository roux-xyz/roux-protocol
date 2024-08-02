// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { CollectionData, EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ICollectionExtension } from "src/interfaces/ICollectionExtension.sol";

contract SetExtension_Collection_Integration_Concrete_Test is CollectionBase {
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
    function test__RevertWhen_SetExtension_NotOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        singleEditionCollection.setExtension(address(mockExtension), true, "");
    }

    /// @dev reverts when setting invalid extension - zero address
    function test__RevertWhen_SetExtension_ZeroAddress() external {
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.Collection_InvalidExtension.selector);
        singleEditionCollection.setExtension(address(0), true, "");
    }

    /// @dev reverts when setting invalid extension
    function test__RevertWhen_SetExtension_InvalidExtension() external {
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.Collection_InvalidExtension.selector);
        singleEditionCollection.setExtension(address(mockExtension), true, "");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully sets extension
    function test__SetExtension() external {
        vm.expectEmit({ emitter: address(singleEditionCollection) });
        emit EventsLib.ExtensionSet(address(mockCollectionExtension), true);

        vm.prank(collectionAdmin);
        singleEditionCollection.setExtension(address(mockCollectionExtension), true, "");

        assertTrue(singleEditionCollection.isExtension(address(mockCollectionExtension)));
    }

    /// @dev successfully sets extension - with mint params
    function test__SetExtension_WithMintParams() external {
        uint128 customPrice = 5 * 10 ** 5;
        uint40 mintStart = uint40(block.timestamp);
        uint40 mintEnd = uint40(block.timestamp + MINT_DURATION);

        vm.expectEmit({ emitter: address(singleEditionCollection) });
        emit EventsLib.ExtensionSet(address(mockCollectionExtension), true);

        vm.prank(collectionAdmin);
        singleEditionCollection.setExtension(
            address(mockCollectionExtension), true, abi.encode(customPrice, mintStart, mintEnd)
        );

        assertTrue(singleEditionCollection.isExtension(address(mockCollectionExtension)));
        assertEq(ICollectionExtension(address(mockCollectionExtension)).price(), customPrice);
    }
}
