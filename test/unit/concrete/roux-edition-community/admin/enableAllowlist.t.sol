// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
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
}
