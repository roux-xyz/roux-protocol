// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { ControllerBase } from "test/shared/ControllerBase.t.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

contract RecordFunds_Controller_Unit_Concrete_Test is ControllerBase {
    function setUp() public override {
        ControllerBase.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when record funds to zero address
    function test__RevertWhen_RecordFunds_ZeroAddress() external {
        // approve
        vm.prank(user);
        mockUSDC.approve(address(controller), type(uint256).max);

        // disburse
        vm.prank(user);
        vm.expectRevert(ErrorsLib.Controller_InvalidFundsRecipient.selector);
        controller.recordFunds(address(0), TOKEN_PRICE);
    }

    /// @dev returns correct balance - after recording funds
    function test__RecordFunds() external {
        // cache starting balance
        uint256 startingBalance = mockUSDC.balanceOf(user);

        // record funds
        vm.prank(user);
        mockUSDC.approve(address(controller), type(uint256).max);

        // expect emit
        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.FundsRecorded({ operator: address(user), recipient: users.user_1, amount: TOKEN_PRICE });

        vm.prank(user);
        controller.recordFunds(users.user_1, TOKEN_PRICE);

        assertEq(controller.balance(users.user_1), TOKEN_PRICE);
        assertEq(mockUSDC.balanceOf(user), startingBalance - TOKEN_PRICE);
    }
}
