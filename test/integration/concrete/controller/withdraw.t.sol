// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { ControllerBase } from "test/shared/ControllerBase.t.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

contract Disburse_Controller_Integration_Concrete_Test is ControllerBase {
    function setUp() public override {
        ControllerBase.setUp();
    }

    function test__Withdraw() external {
        // get funds recipient
        address fundsRecipient = controller.fundsRecipient(address(edition), 1);

        // cache starting balance
        uint256 fundsRecipientStartingBalance = mockUSDC.balanceOf(fundsRecipient);

        // mint
        _mintToken(edition, 1, user);

        // check balance
        assertEq(controller.balance(fundsRecipient), TOKEN_PRICE);

        // expect withdrawal to be emitted
        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.Withdrawn({ recipient: fundsRecipient, amount: TOKEN_PRICE });

        // withdraw
        controller.withdraw(fundsRecipient);

        // check balance
        assertEq(mockUSDC.balanceOf(fundsRecipient), fundsRecipientStartingBalance + TOKEN_PRICE);
    }

    function test__Withdraw_Fork_1() external {
        // cache starting balance
        uint256 creator0StartingBalance = mockUSDC.balanceOf(creator);
        uint256 creator1StartingBalance = mockUSDC.balanceOf(users.creator_1);

        // create fork
        (RouxEdition forkEdition, uint256 tokenId) = _createFork(edition, 1, users.creator_1);

        // approve fork
        _approveToken(address(forkEdition), user);

        // compute split
        (uint256 parentShare, uint256 childShare) = _computeSplit(edition, tokenId, TOKEN_PRICE);

        // mint
        _mintToken(forkEdition, tokenId, user);

        // disburse pending from original edition
        controller.distributePending(address(edition), tokenId);

        // get funds recipient
        address fundsRecipient = controller.fundsRecipient(address(edition), 1);

        // check balances
        assertEq(controller.pending(address(edition), 1), 0);
        assertEq(controller.balance(fundsRecipient), parentShare);

        // withdraw - fork
        vm.prank(users.creator_1);
        controller.withdraw(controller.fundsRecipient(address(forkEdition), 1));

        // withdraw - original
        vm.prank(creator);
        controller.withdraw(controller.fundsRecipient(address(edition), 1));

        // check balances
        assertEq(mockUSDC.balanceOf(address(creator)), creator0StartingBalance + parentShare);
        assertEq(mockUSDC.balanceOf(address(users.creator_1)), creator1StartingBalance + childShare);
    }
}
