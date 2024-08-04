// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract SetExtension_RouxEdition_Integration_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev only owner can set extension
    function test__RevertWhen_OnlyOwner_SetExtension() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.setExtension(1, address(mockExtension), true, "");
    }

    /// @dev only owner can disable extension
    function test__RevertWhen_OnlyOwner_DisableExtension() external {
        vm.prank(creator);
        edition.setExtension(1, address(mockExtension), true, "");

        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.setExtension(1, address(0), false, "");
    }

    /// @dev reverts when extension is zero address
    function test__RevertWhen_SetExtension_ZeroAddress() external {
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidExtension.selector);
        edition.setExtension(1, address(0), true, "");
    }

    /// @dev reverts when extension interface is not supported
    function test__RevertWhen_SetExtension_InvalidInterface() external {
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidExtension.selector);
        edition.setExtension(1, address(edition), true, "");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully sets extension
    function test__SetExtension() external useEditionAdmin(edition) {
        vm.expectEmit({ emitter: address(edition) });
        emit EventsLib.ExtensionSet(address(mockExtension), 1, true);

        edition.setExtension(1, address(mockExtension), true, "");

        assertTrue(edition.isRegisteredExtension(1, address(mockExtension)));
    }

    /// @dev successfully disables extension
    function test__DisableExtension() external useEditionAdmin(edition) {
        edition.setExtension(1, address(mockExtension), true, "");

        assertTrue(edition.isRegisteredExtension(1, address(mockExtension)));

        vm.expectEmit({ emitter: address(edition) });
        emit EventsLib.ExtensionSet(address(mockExtension), 1, false);

        edition.setExtension(1, address(mockExtension), false, "");

        assertFalse(edition.isRegisteredExtension(1, address(mockExtension)));
    }

    /// @dev set extension with mint params
    function test__SetExtension_WithMintParams() external useEditionAdmin(edition) {
        uint128 customPrice = 5 * 10 ** 5;

        edition.setExtension(1, address(mockExtension), true, abi.encode(customPrice));

        assertEq(mockExtension.price(address(edition), 1), customPrice);
        assertTrue(edition.isRegisteredExtension(1, address(mockExtension)));
    }
}
