// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { MultiEditionCollection } from "src/core/MultiEditionCollection.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { CollectionData, EditionData } from "src/types/DataTypes.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";

contract Mint_MultiEditionCollection_Unit_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual override {
        CollectionBase.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when unregistered extension is provided
    function test__RevertWhen_UnregisteredExtension() external {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.Collection_InvalidExtension.selector);
        multiEditionCollection.mint({ to: user, extension: address(mockExtension), referrer: address(0), data: "" });
    }

    // @dev reverts when mint is gated and no extension is provided
    function test__RevertWhen_MintIsGatedAndNoExtension() external {
        // gate collection
        vm.prank(curator);
        multiEditionCollection.gateMint(true);

        vm.prank(user);
        vm.expectRevert(ErrorsLib.Collection_GatedMint.selector);
        multiEditionCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });
    }

    // @dev reverts when mint is gated and unregistered extension is provided
    function test__RevertWhen_MintIsGatedAndUnregisteredExtension() external {
        // gate collection
        vm.prank(curator);
        multiEditionCollection.gateMint(true);

        vm.prank(user);
        vm.expectRevert(ErrorsLib.Collection_InvalidExtension.selector);
        multiEditionCollection.mint({ to: user, extension: address(mockExtension), referrer: address(0), data: "" });
    }
}
