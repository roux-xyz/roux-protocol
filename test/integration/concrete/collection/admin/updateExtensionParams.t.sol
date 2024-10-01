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
import { IExtension } from "src/interfaces/IExtension.sol";
import { MockCollectionExtension } from "test/mocks/MockCollectionExtension.sol";

contract UpdateExtensionParams_Collection_Integration_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual override {
        CollectionBase.setUp();

        // Set up the extension
        uint128 customPrice = 5 * 10 ** 5;
        uint40 mintStart = uint40(block.timestamp);
        uint40 mintEnd = uint40(block.timestamp + MINT_DURATION);

        vm.startPrank(collectionAdmin);
        singleEditionCollection.setExtension(
            address(mockCollectionExtension), true, abi.encode(customPrice, mintStart, mintEnd)
        );
        vm.stopPrank();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when not owner
    function test__RevertWhen_UpdateExtensionParams_NotOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        singleEditionCollection.updateExtensionParams(address(mockCollectionExtension), "");
    }

    /// @dev reverts when updating params for non-existent extension
    function test__RevertWhen_UpdateExtensionParams_NonExistentExtension() external {
        vm.prank(collectionAdmin);
        vm.expectRevert(ErrorsLib.Collection_InvalidExtension.selector);
        singleEditionCollection.updateExtensionParams(address(mockExtension), "");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates extension params
    function test__UpdateExtensionParams() external {
        uint128 newPrice = 10 * 10 ** 6; // 10 USDC
        uint40 newMintStart = uint40(block.timestamp + 1 days);
        uint40 newMintEnd = uint40(block.timestamp + 30 days);

        bytes memory newParams = abi.encode(newPrice, newMintStart, newMintEnd);

        vm.prank(collectionAdmin);
        singleEditionCollection.updateExtensionParams(address(mockCollectionExtension), newParams);

        // Verify the new price was set
        assertEq(
            MockCollectionExtension(address(mockCollectionExtension)).price(address(singleEditionCollection), 0),
            newPrice
        );

        vm.stopPrank();
    }
}
