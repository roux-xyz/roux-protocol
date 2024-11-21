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
        RouxCommunityEdition(address(communityEdition)).addToAllowlist(addresses);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev add to allowlist
    function test__AddToAllowlist() external {
        // enable allowlist
        vm.prank(creator);
        RouxCommunityEdition(address(communityEdition)).enableAllowlist(true);

        // check initial state
        assertEq(RouxCommunityEdition(address(communityEdition)).isAllowlisted(creator), false);
        assertEq(RouxCommunityEdition(address(communityEdition)).isAllowlisted(user), false);

        vm.prank(creator);
        RouxCommunityEdition(address(communityEdition)).addToAllowlist(addresses);

        assertEq(RouxCommunityEdition(address(communityEdition)).isAllowlisted(creator), true);
        assertEq(RouxCommunityEdition(address(communityEdition)).isAllowlisted(user), true);
    }

    /// @dev add to allowlist - admin role
    function test__AddToAllowlist_AdminRole() external {
        // enable allowlist
        vm.prank(creator);
        RouxCommunityEdition(address(communityEdition)).enableAllowlist(true);

        uint256 ROLE = RouxCommunityEdition(address(communityEdition)).ADMIN_ROLE();

        vm.prank(creator);
        OwnableRoles(address(communityEdition)).grantRoles(user, ROLE);

        vm.prank(user);
        RouxCommunityEdition(address(communityEdition)).addToAllowlist(addresses);

        assertEq(RouxCommunityEdition(address(communityEdition)).isAllowlisted(creator), true);
        assertEq(RouxCommunityEdition(address(communityEdition)).isAllowlisted(user), true);
    }

    /// @dev add to allowlist - allowlist admin role
    function test__AddToAllowlist_AllowlistAdminRole() external {
        // enable allowlist
        vm.prank(creator);
        RouxCommunityEdition(address(communityEdition)).enableAllowlist(true);

        uint256 ROLE = RouxCommunityEdition(address(communityEdition)).ALLOWLIST_ADMIN_ROLE();

        vm.prank(creator);
        OwnableRoles(address(communityEdition)).grantRoles(user, ROLE);

        vm.prank(user);
        RouxCommunityEdition(address(communityEdition)).addToAllowlist(addresses);

        assertEq(RouxCommunityEdition(address(communityEdition)).isAllowlisted(creator), true);
        assertEq(RouxCommunityEdition(address(communityEdition)).isAllowlisted(user), true);
    }
}
