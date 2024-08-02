// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { ControllerBase } from "test/shared/ControllerBase.t.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { Initializable } from "solady/utils/Initializable.sol";

contract Pause_Controller_Integration_Concrete_Test is ControllerBase {
    function setUp() public override {
        ControllerBase.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev only owner can pause
    function test__RevertWhen_Pause_OnlyOwner() external {
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.pause(true);
    }

    /// @dev functions with modifiers revert when paused
    function test__RevertWhen_Paused() external {
        // pause
        vm.prank(users.deployer);
        controller.pause(true);

        vm.startPrank(user);

        vm.expectRevert(ErrorsLib.Controller_Paused.selector);
        controller.disburse(address(edition), 1, TOKEN_PRICE, address(0));

        vm.expectRevert(ErrorsLib.Controller_Paused.selector);
        controller.recordFunds(users.user_1, TOKEN_PRICE);

        vm.expectRevert(ErrorsLib.Controller_Paused.selector);
        controller.distributePending(address(edition), 1);

        vm.expectRevert(ErrorsLib.Controller_Paused.selector);
        controller.distributePendingAndWithdraw(address(edition), 1);

        vm.expectRevert(ErrorsLib.Controller_Paused.selector);
        controller.withdraw(users.user_1);

        vm.expectRevert(ErrorsLib.Controller_Paused.selector);
        controller.setFundsRecipient(1, users.user_1);

        vm.expectRevert(ErrorsLib.Controller_Paused.selector);
        controller.setProfitShare(1, PROFIT_SHARE + 1);

        vm.expectRevert(ErrorsLib.Controller_Paused.selector);
        controller.setControllerData(1, users.user_1, PROFIT_SHARE + 1);
    }
}
