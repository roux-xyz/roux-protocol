// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { RouxCommunityEdition } from "src/core/RouxCommunityEdition.sol";

contract UpdateAddWindow_RouxCommunityEdition_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when not owner
    function test__RevertWhen_UpdateAddWindow_NotOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        RouxCommunityEdition(address(communityEdition)).updateAddWindow(
            uint40(block.timestamp), uint40(block.timestamp + 1 days)
        );
    }

    /// @dev reverts when start time is greater than end time
    function test__RevertWhen_UpdateAddWindow_StartGreaterThanEnd() external {
        uint40 startTime = uint40(block.timestamp + 2 days);
        uint40 endTime = uint40(block.timestamp + 1 days);

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxCommunityEdition_InvalidAddWindow.selector);
        RouxCommunityEdition(address(communityEdition)).updateAddWindow(startTime, endTime);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates add window
    function test__UpdateAddWindow() external {
        uint40 startTime = uint40(block.timestamp + 1 days);
        uint40 endTime = uint40(block.timestamp + 2 days);

        vm.prank(creator);
        RouxCommunityEdition(address(communityEdition)).updateAddWindow(startTime, endTime);

        (uint40 newStart, uint40 newEnd) = RouxCommunityEdition(address(communityEdition)).addWindow();
        assertEq(newStart, startTime);
        assertEq(newEnd, endTime);
    }
}
