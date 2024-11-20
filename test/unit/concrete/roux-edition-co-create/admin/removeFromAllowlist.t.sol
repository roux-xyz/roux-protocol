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

    address[] addresses = new address[](2);

    function setUp() public override {
        BaseTest.setUp();

        addresses[0] = creator;
        addresses[1] = user;
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev only owner
    function test__RevertWhen_OnlyOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        RouxEditionCoCreate(address(coCreateEdition)).removeFromAllowlist(user);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev remove from allowlist
    function test__RemoveFromAllowlist() external {
        // enable allowlist
        vm.prank(creator);
        RouxEditionCoCreate(address(coCreateEdition)).enableAllowlist(true);

        // check initial state
        assertEq(RouxEditionCoCreate(address(coCreateEdition)).isAllowlisted(creator), false);
        assertEq(RouxEditionCoCreate(address(coCreateEdition)).isAllowlisted(user), false);

        vm.prank(creator);
        RouxEditionCoCreate(address(coCreateEdition)).addToAllowlist(addresses);

        assertEq(RouxEditionCoCreate(address(coCreateEdition)).isAllowlisted(creator), true);
        assertEq(RouxEditionCoCreate(address(coCreateEdition)).isAllowlisted(user), true);

        vm.prank(creator);
        RouxEditionCoCreate(address(coCreateEdition)).removeFromAllowlist(user);

        assertEq(RouxEditionCoCreate(address(coCreateEdition)).isAllowlisted(creator), true);
        assertEq(RouxEditionCoCreate(address(coCreateEdition)).isAllowlisted(user), false);
    }
}
