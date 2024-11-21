// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { RouxCommunityEdition } from "src/core/RouxCommunityEdition.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";

contract EnableAllowlist_RouxCommunityEdition_Unit_Concrete_Test is BaseTest {
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
        RouxCommunityEdition(address(communityEdition)).enableAllowlist(true);
    }

    /// @dev allowslist admin cannot enable allowlist (can add or remove only)
    function test__RevertWhen_AllowlistAdminCannotEnableAllowlist() external {
        uint256 ROLE = RouxCommunityEdition(address(communityEdition)).ALLOWLIST_ADMIN_ROLE();

        vm.prank(creator);
        OwnableRoles(address(communityEdition)).grantRoles(user, ROLE);

        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        RouxCommunityEdition(address(communityEdition)).enableAllowlist(true);
    }

    /* -------------------------------------------- */
    /* view                                        */
    /* -------------------------------------------- */

    /// @dev get allowlist enabled
    function test__GetAllowlistEnabled() external view {
        assertEq(RouxCommunityEdition(address(communityEdition)).isAllowlistEnabled(), false);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev set allowlist enabled
    function test__SetAllowlistEnabled() external {
        vm.prank(creator);
        RouxCommunityEdition(address(communityEdition)).enableAllowlist(true);

        assertEq(RouxCommunityEdition(address(communityEdition)).isAllowlistEnabled(), true);

        vm.prank(users.creator_1);
        vm.expectRevert(ErrorsLib.RouxCommunityEdition_NotAllowed.selector);
        communityEdition.add(defaultAddParams);
    }

    /// @dev set allowlist enabled - admin role
    function test__SetAllowlistEnabled_AdminRole() external {
        uint256 ROLE = RouxCommunityEdition(address(communityEdition)).ADMIN_ROLE();

        vm.prank(creator);
        OwnableRoles(address(communityEdition)).grantRoles(user, ROLE);

        vm.prank(user);
        RouxCommunityEdition(address(communityEdition)).enableAllowlist(true);

        assertEq(RouxCommunityEdition(address(communityEdition)).isAllowlistEnabled(), true);
    }
}
