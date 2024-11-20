// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { RouxEditionCoCreate } from "src/core/RouxEditionCoCreate.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";

contract EnableAllowlist_RouxEditionCoCreate_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev only owner
    function test__RevertWhen_OnlyOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        RouxEditionCoCreate(address(coCreateEdition)).enableAllowlist(true);
    }

    /* -------------------------------------------- */
    /* view                                        */
    /* -------------------------------------------- */

    /// @dev get allowlist enabled
    function test__GetAllowlistEnabled() external view {
        assertEq(RouxEditionCoCreate(address(coCreateEdition)).isAllowlistEnabled(), false);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev set allowlist enabled
    function test__SetAllowlistEnabled() external {
        vm.prank(creator);
        RouxEditionCoCreate(address(coCreateEdition)).enableAllowlist(true);

        assertEq(RouxEditionCoCreate(address(coCreateEdition)).isAllowlistEnabled(), true);

        vm.prank(users.creator_1);
        vm.expectRevert(ErrorsLib.RouxEditionCoCreate_NotAllowed.selector);
        coCreateEdition.add(defaultAddParams);
    }
}
