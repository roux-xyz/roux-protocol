// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

/**
 * @title ControllerBase test
 */
abstract contract ControllerBase is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();

        // approve test edition to spend mock usdc
        _approveToken(address(edition), user);
    }

    /* -------------------------------------------- */
    /* utility functions                            */
    /* -------------------------------------------- */

    /// @dev get index of recipient in recipient array
    function _getRecipientIndex(address recipient, address[] memory recipientArray) internal pure returns (uint256) {
        uint256 recipientIndex = type(uint256).max;
        for (uint256 j = 0; j < recipientArray.length; j++) {
            if (recipientArray[j] == recipient) {
                recipientIndex = j;
                break;
            }
        }
        if (recipientIndex == type(uint256).max) revert("recipient not found in creatorArray");

        return recipientIndex;
    }

    /// @dev test distributePending
    function _test__distributePending(uint256 numForks) internal {
        // create forks
        RouxEdition[] memory editions = _createForks(numForks);

        // validate length
        assertEq(editions.length, numForks + 1);

        // approve last fork
        _approveToken(address(editions[editions.length - 1]), user);

        // create running balances array
        uint256[] memory runningBalances = new uint256[](creatorArray.length);

        // mint last fork
        _mintToken(editions[editions.length - 1], 1, user);

        // initialize remaining amount
        uint256 remainingAmount = TOKEN_PRICE;

        // process editions
        for (uint256 i = editions.length - 1; i >= 0; i--) {
            // get recipient
            address recipient = controller.fundsRecipient(address(editions[i]), 1);

            // get recipient index
            uint256 recipientIndex = _getRecipientIndex(recipient, creatorArray);

            // get current balance
            uint256 currentBalance = controller.balance(recipient);

            // get current pending
            uint256 currentPending = controller.pending(address(editions[i]), 1);

            // last fork
            if (i == editions.length - 1) {
                (uint256 parentShare, uint256 childShare) = _computeSplit(editions[i - 1], 1, remainingAmount);

                // update running balances
                runningBalances[recipientIndex] += childShare;

                // validate balances
                assertEq(currentBalance, runningBalances[recipientIndex], "last fork balance incorrect");
                assertEq(currentPending, 0, "last fork pending should be 0");

                // update remaining amount
                remainingAmount = parentShare;
            } else {
                // validate pending
                assertApproxEqAbs(currentPending, remainingAmount, 1, "pending amount incorrect");

                // call disburse pending (anyone can call)
                controller.distributePending(address(editions[i]), 1);

                // calculate running balance if not root
                if (i > 0) {
                    // compute split
                    (uint256 parentShare, uint256 childShare) = _computeSplit(editions[i - 1], 1, remainingAmount);

                    // update running balances
                    runningBalances[recipientIndex] += childShare;

                    // validate balances
                    assertApproxEqAbs(
                        controller.balance(recipient),
                        runningBalances[recipientIndex],
                        1,
                        "balance after disburse incorrect"
                    );

                    // validate pending
                    assertApproxEqAbs(
                        controller.pending(address(editions[i]), 1), 0, 1, "pending after disburse should be 0"
                    );

                    // update remaining amount
                    remainingAmount = parentShare;
                } else {
                    // calculate balance if root - update running balance with remaining amount
                    runningBalances[recipientIndex] += remainingAmount;

                    // validate balances
                    assertApproxEqAbs(
                        controller.balance(recipient),
                        runningBalances[recipientIndex],
                        1,
                        "root balance after disburse incorrect"
                    );

                    // validate pending
                    assertEq(controller.pending(address(editions[i]), 1), 0, "root pending after disburse should be 0");

                    // remaining amount is now 0
                    remainingAmount = 0;
                }
            }

            if (i == 0) break; // Break the loop when i becomes 0 to avoid underflow
        }

        uint256 totalDistributed = 0;
        for (uint256 j = 0; j < creatorArray.length; j++) {
            uint256 actualBalance = controller.balance(creatorArray[j]);
            totalDistributed += actualBalance;
            assertApproxEqAbs(actualBalance, runningBalances[j], 1, "final balance mismatch");
        }
        assertEq(totalDistributed, TOKEN_PRICE, "total distributed not equal to token price");
    }

    /// @dev test distributePendingAndWithdraw
    function _test__distributePendingAndWithdraw(uint256 numForks) internal {
        // create forks
        RouxEdition[] memory editions = _createForks(numForks);

        // validate length
        assertEq(editions.length, numForks + 1, "length should be numForks + 1");

        // approve last fork
        _approveToken(address(editions[editions.length - 1]), user);

        // create running withdrawal amounts array
        uint256[] memory runningWithdrawals = new uint256[](creatorArray.length);

        // store initial balances
        uint256[] memory initialBalances = new uint256[](creatorArray.length);
        for (uint256 i = 0; i < creatorArray.length; i++) {
            initialBalances[i] = mockUSDC.balanceOf(creatorArray[i]);
        }

        // mint last fork
        _mintToken(editions[editions.length - 1], 1, user);

        // initialize remaining amount
        uint256 remainingAmount = TOKEN_PRICE;

        // process editions
        for (uint256 i = editions.length - 1; i >= 0; i--) {
            // get recipient
            address recipient = controller.fundsRecipient(address(editions[i]), 1);

            // get recipient index
            uint256 recipientIndex = type(uint256).max;
            for (uint256 j = 0; j < creatorArray.length; j++) {
                if (creatorArray[j] == recipient) {
                    recipientIndex = j;
                    break;
                }
            }
            if (recipientIndex == type(uint256).max) revert("recipient not found in creatorArray");

            // get current pending
            uint256 currentPending = controller.pending(address(editions[i]), 1);

            // last fork
            if (i == editions.length - 1) {
                (uint256 parentShare, uint256 childShare) = _computeSplit(editions[i - 1], 1, remainingAmount);

                // update running withdrawals
                runningWithdrawals[recipientIndex] += childShare;

                // validate pending
                assertEq(currentPending, 0, "last fork pending should be 0");

                // call normal withdraw for last fork
                controller.withdraw(recipient);

                // validate actual withdrawal
                assertApproxEqAbs(
                    mockUSDC.balanceOf(recipient) - initialBalances[recipientIndex],
                    runningWithdrawals[recipientIndex],
                    1,
                    "last fork withdrawal incorrect"
                );

                // update remaining amount
                remainingAmount = parentShare;
            } else {
                // validate pending
                assertApproxEqAbs(currentPending, remainingAmount, 1, "pending amount incorrect");

                // call disburse pending and withdraw
                controller.distributePendingAndWithdraw(address(editions[i]), 1);

                if (i > 0) {
                    // compute split
                    (uint256 parentShare, uint256 childShare) = _computeSplit(editions[i - 1], 1, remainingAmount);

                    // update running withdrawals
                    runningWithdrawals[recipientIndex] += childShare;

                    // validate actual withdrawal
                    assertApproxEqAbs(
                        mockUSDC.balanceOf(recipient) - initialBalances[recipientIndex],
                        runningWithdrawals[recipientIndex],
                        1,
                        "withdrawal incorrect"
                    );

                    // validate pending is now 0
                    assertEq(controller.pending(address(editions[i]), 1), 0, "pending after withdraw should be 0");

                    // update remaining amount
                    remainingAmount = parentShare;
                } else {
                    // root edition - withdraw remaining amount
                    runningWithdrawals[recipientIndex] += remainingAmount;

                    // validate actual withdrawal
                    assertApproxEqAbs(
                        mockUSDC.balanceOf(recipient) - initialBalances[recipientIndex],
                        runningWithdrawals[recipientIndex],
                        1,
                        "root withdrawal incorrect"
                    );

                    // validate pending
                    assertEq(controller.pending(address(editions[i]), 1), 0, "root pending after withdraw should be 0");

                    // remaining amount is now 0
                    remainingAmount = 0;
                }
            }

            if (i == 0) break; // Break the loop when i becomes 0 to avoid underflow
        }

        uint256 totalWithdrawn = 0;
        for (uint256 j = 0; j < creatorArray.length; j++) {
            uint256 actualWithdrawn = mockUSDC.balanceOf(creatorArray[j]) - initialBalances[j];
            totalWithdrawn += actualWithdrawn;
            assertApproxEqAbs(actualWithdrawn, runningWithdrawals[j], 1, "final withdrawal mismatch");
        }

        assertEq(totalWithdrawn, TOKEN_PRICE, "total withdrawn not equal to token price");
    }
}
