// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";

contract SetExtension_RouxEdition_Unit_Concrete_Test is BaseTest {
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
        vm.prank(users.user_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.setExtension(1, address(mockExtension), true, "");
    }

    /// @dev only owner can disable extension
    function test__RevertWhen_OnlyOwner_DisableExtension() external {
        // add extension to token
        vm.prank(users.creator_0);
        edition.setExtension(1, address(mockExtension), true, "");

        vm.prank(users.user_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.setExtension(1, address(0), false, "");
    }

    /// @dev reverts when extension is zero address
    function test__RevertWhen_SetExtension_ZeroAddress() external {
        vm.prank(users.creator_0);
        vm.expectRevert(IRouxEdition.InvalidExtension.selector);
        edition.setExtension(1, address(0), true, "");
    }

    /// @dev reverts when extension interface is not supported
    function test__RevertWhen_SetExtension_InvalidInterface() external {
        vm.prank(users.creator_0);
        vm.expectRevert(IRouxEdition.InvalidExtension.selector);
        edition.setExtension(1, address(edition), true, "");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully sets extension
    function test__SetExtension() external {
        // event
        vm.expectEmit({ emitter: address(edition) });
        emit ExtensionSet(address(mockExtension), 1, true);

        // add extension to token
        vm.prank(users.creator_0);
        edition.setExtension(1, address(mockExtension), true, "");

        assertTrue(edition.isExtension(1, address(mockExtension)));
    }

    /// @dev successfully disables extension
    function test__DisableExtension() external {
        // add extension to token
        vm.prank(users.creator_0);
        edition.setExtension(1, address(mockExtension), true, "");

        assertTrue(edition.isExtension(1, address(mockExtension)));

        // event
        vm.expectEmit({ emitter: address(edition) });
        emit ExtensionSet(address(mockExtension), 1, false);

        // disable extension
        vm.prank(users.creator_0);
        edition.setExtension(1, address(mockExtension), false, "");

        assertFalse(edition.isExtension(1, address(mockExtension)));
    }

    /// @dev set extension with mint params
    function test__SetExtension_WithMintParams() external {
        uint128 customPrice = 5 * 10 ** 5; // $0.50 USDC

        // add extension to token
        vm.prank(users.creator_0);
        edition.setExtension(1, address(mockExtension), true, abi.encode(customPrice));

        assertEq(mockExtension.price(address(edition), 1), customPrice);
        assertTrue(edition.isExtension(1, address(mockExtension)));
    }
}
