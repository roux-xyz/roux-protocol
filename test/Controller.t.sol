// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IController } from "src/interfaces/IController.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { EditionData } from "src/types/DataTypes.sol";

import "forge-std/console.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract ControllerTest is BaseTest {
    address testMinter;

    function setUp() public virtual override {
        BaseTest.setUp();

        // set test edition minter
        testMinter = address(users.user_0);

        // approve test edition to spend mock usdc
        _approveToken(address(edition), testMinter);
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    function test__RevertWhen_SetController_FundsRecipientIsZero() external {
        // modifiy default add params
        defaultAddParams.fundsRecipient = address(0);

        vm.prank(users.creator_0);
        vm.expectRevert(IController.InvalidFundsRecipient.selector);
        edition.add(defaultAddParams);
    }

    function test__RevertWhen_SetController_ProfitShareTooHigh() external {
        // create new edition instance
        _createEdition(users.creator_0);

        // modify default add params
        defaultAddParams.profitShare = 10_001;
        defaultAddParams.parentEdition = address(edition);
        defaultAddParams.parentTokenId = 1;

        vm.prank(users.creator_0);
        vm.expectRevert(IController.InvalidProfitShare.selector);
        edition.add(defaultAddParams);
    }

    function test__RevertWhen_EnablePlatformFee_OnlyOwner() external {
        // attempt to enable minting
        vm.prank(users.creator_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.enablePlatformFee(true);
    }

    function test__RevertWhen_UpgradeToAndCall_OnlyOwner() external {
        // attempt to upgrade to and call
        vm.prank(users.creator_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.upgradeToAndCall(address(edition), "");
    }

    function test__RevertWhen_AlreadyInitialized() external {
        // attempt to initialize
        vm.expectRevert(bytes("Already initialized"));
        controller.initialize();
    }

    /* -------------------------------------------- */
    /* view                                        */
    /* -------------------------------------------- */

    function test__Currency() external {
        assertEq(controller.currency(), address(edition.currency()));
        assertEq(controller.currency(), address(mockUSDC));
    }

    function test__Owner() external {
        assertEq(controller.owner(), address(users.deployer));
    }

    function test__ProfitShare() external {
        assertEq(controller.profitShare(address(edition), 1), PROFIT_SHARE);
    }

    function test__FundsRecipient() external {
        assertEq(controller.fundsRecipient(address(edition), 1), users.creator_0);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function test__AddToken_SetControllerData() external {
        (, uint256 tokenId) = _addToken(edition);

        assertEq(tokenId, 2);

        // verify token config
        assertEq(controller.fundsRecipient(address(edition), tokenId), defaultAddParams.fundsRecipient);
        assertEq(controller.profitShare(address(edition), tokenId), PROFIT_SHARE);
    }

    function test__Mint() external {
        // expect disbursement to be emitted
        vm.expectEmit({ emitter: address(controller) });
        emit Deposited({ recipient: controller.fundsRecipient(address(edition), 1), amount: TOKEN_PRICE });

        // mint
        _mintToken(edition, 1, testMinter);

        // check balance
        assertEq(controller.balance(controller.fundsRecipient(address(edition), 1)), TOKEN_PRICE);
    }

    function test__Mint_Fork() external {
        // create fork
        (RouxEdition forkEdition, uint256 tokenId) = _createFork(edition, 1, users.creator_1);

        // approve fork
        _approveToken(address(forkEdition), testMinter);

        // compute split
        (uint256 parentShare, uint256 childShare) = _computeSplit(edition, tokenId, TOKEN_PRICE);

        // expect deposit to be emitted
        vm.expectEmit({ emitter: address(controller) });
        emit Deposited({ recipient: controller.fundsRecipient(address(forkEdition), 1), amount: childShare });

        // expect pending to be emitted
        vm.expectEmit({ emitter: address(controller) });
        emit PendingUpdated({
            edition: address(forkEdition),
            tokenId: 1,
            parent: address(edition),
            parentTokenId: 1,
            amount: parentShare
        });

        // mint
        _mintToken(forkEdition, tokenId, testMinter);

        // check balance
        assertEq(controller.balance(controller.fundsRecipient(address(forkEdition), 1)), childShare);
        assertEq(controller.pending(address(edition), 1), parentShare);
    }

    function test__Mint_Referral() external {
        // compute referral fee
        uint256 referralFee = (TOKEN_PRICE * controller.REFERRAL_FEE()) / 10_000;

        // mint
        vm.prank(users.user_0);
        edition.mint(users.user_0, 1, 1, users.user_0, address(0), "");

        // check balance
        assertEq(controller.balance(controller.fundsRecipient(address(edition), 1)), TOKEN_PRICE - referralFee);
        assertEq(controller.balance(users.user_0), referralFee);
    }

    function test__Mint_Fork_Referral() external {
        // create fork
        (RouxEdition forkEdition, uint256 tokenId) = _createFork(edition, 1, users.creator_1);

        // approve fork
        _approveToken(address(forkEdition), testMinter);

        // compute referral fee
        uint256 referralFee = (TOKEN_PRICE * controller.REFERRAL_FEE()) / 10_000;

        // mint with referral
        vm.prank(users.user_0);
        forkEdition.mint(users.user_0, tokenId, 1, users.user_1, address(0), "");

        // compute split
        (uint256 parentShare, uint256 childShare) = _computeSplit(edition, tokenId, TOKEN_PRICE - referralFee);

        // check balances
        assertEq(controller.balance(controller.fundsRecipient(address(forkEdition), tokenId)), childShare);
        assertEq(controller.pending(address(edition), 1), parentShare);
        assertEq(controller.balance(users.user_1), referralFee);
    }

    function test__RecordFunds() external {
        // approve
        vm.prank(users.user_0);
        mockUSDC.approve(address(controller), type(uint256).max);

        // record funds
        vm.prank(users.user_0);
        controller.recordFunds(users.user_1, TOKEN_PRICE);

        // check balance
        assertEq(controller.balance(users.user_1), TOKEN_PRICE);
    }

    function test__DisbursePending_Fork_1() external {
        // create fork
        (RouxEdition forkEdition, uint256 tokenId) = _createFork(edition, 1, users.creator_1);

        // approve fork
        _approveToken(address(forkEdition), testMinter);

        // compute split
        (uint256 parentShare,) = _computeSplit(edition, tokenId, TOKEN_PRICE);

        // mint
        _mintToken(forkEdition, tokenId, testMinter);

        // disburse pending from original edition
        controller.disbursePending(address(edition), tokenId);

        // get funds recipient
        address fundsRecipient = controller.fundsRecipient(address(edition), 1);

        // check balances
        assertEq(controller.pending(address(edition), 1), 0);
        assertEq(controller.balance(fundsRecipient), parentShare);
    }

    function test__DisbursePending_Fork_2() external {
        _disburse_pending(2);
    }

    function test__DisbursePending_Fork_3() external {
        _disburse_pending(3);
    }

    function test__DisbursePending_Fork_4() external {
        _disburse_pending(4);
    }

    function test__DisbursePending_Fork_5() external {
        _disburse_pending(5);
    }

    function test__DisbursePending_Fork_6() external {
        _disburse_pending(6);
    }

    function test__DisbursePending_Fork_7() external {
        _disburse_pending(7);
    }

    function test__DisbursePending_Fork_8() external {
        _disburse_pending(8);
    }

    function test__Mint_Fork_3() external {
        // create forks
        RouxEdition[] memory editions = _createForks(3);

        // approve fork
        _approveToken(address(editions[3]), testMinter);

        // assert length is 4 (original + 3 forks)
        assertEq(editions.length, 4, "length should be 4");

        // mint token
        _mintToken(editions[3], 1, testMinter);

        // get funds recipient
        address fork3fundsRecipient = controller.fundsRecipient(address(editions[3]), 1);

        // compute split
        (uint256 parentShareToFork2, uint256 childShareToFork3) = _computeSplit(editions[3], 1, TOKEN_PRICE);

        // check recipient balance
        assertEq(controller.balance(fork3fundsRecipient), childShareToFork3);

        // check pending balance
        assertEq(controller.pending(address(editions[2]), 1), parentShareToFork2);
    }

    function test__DisbursePendingBatch_Fork_3() external {
        // create original edition and 3 forks
        RouxEdition[] memory editions = _createForks(3);

        // approve and mint on the last fork
        _approveToken(address(editions[3]), testMinter);
        _mintToken(editions[3], 1, testMinter);

        // create running balances array
        uint256[] memory runningBalances = new uint256[](creatorArray.length);

        // prepare arrays for batch disburse
        address[] memory editionAddresses = new address[](3);
        uint256[] memory tokenIds = new uint256[](3);

        for (uint256 i = 0; i < 3; i++) {
            editionAddresses[i] = address(editions[2 - i]); // 2nd fork, 1st fork, original
            tokenIds[i] = 1;
        }

        // compute expected splits + update running balances using _computeSplit and _getRecipientIndex
        // fork 3
        (uint256 parentShare2, uint256 childShare3) = _computeSplit(editions[2], 1, TOKEN_PRICE);
        address edition3recipient = controller.fundsRecipient(address(editions[3]), 1);
        runningBalances[_getRecipientIndex(edition3recipient, creatorArray)] += childShare3;

        // fork 2
        (uint256 parentShare1, uint256 childShare2) = _computeSplit(editions[1], 1, parentShare2);
        address edition2recipient = controller.fundsRecipient(address(editions[2]), 1);
        runningBalances[_getRecipientIndex(edition2recipient, creatorArray)] += childShare2;

        // fork 1
        (uint256 parentShare0, uint256 childShare1) = _computeSplit(editions[0], 1, parentShare1);
        address edition1recipient = controller.fundsRecipient(address(editions[1]), 1);
        runningBalances[_getRecipientIndex(edition1recipient, creatorArray)] += childShare1;

        // root
        address edition0recipient = controller.fundsRecipient(address(editions[0]), 1);
        runningBalances[_getRecipientIndex(edition0recipient, creatorArray)] += parentShare0;

        // call disbursePendingBatch
        controller.disbursePendingBatch(editionAddresses, tokenIds);

        // check balances and pending amounts
        for (uint256 i = 0; i < creatorArray.length; i++) {
            assertEq(controller.balance(creatorArray[i]), runningBalances[i], "final balance mismatch");
        }

        for (uint256 i = 0; i < editions.length; i++) {
            assertEq(controller.pending(address(editions[i]), 1), 0, "pending should be 0 for all editions");
        }

        // verify total balance matches the initial mint price
        uint256 totalBalance = childShare3 + childShare2 + childShare1 + parentShare0;
        assertEq(totalBalance, TOKEN_PRICE, "total balance should match initial mint price");
    }

    function test__Withdraw() external {
        // get funds recipient
        address fundsRecipient = controller.fundsRecipient(address(edition), 1);

        // cache starting balance
        uint256 fundsRecipientStartingBalance = mockUSDC.balanceOf(fundsRecipient);

        // mint
        _mintToken(edition, 1, testMinter);

        // check balance
        assertEq(controller.balance(fundsRecipient), TOKEN_PRICE);

        // expect withdrawal to be emitted
        // vm.expectEmit({emitter: address(controller)});
        // emit Withdrawn({recipient: fundsRecipient, amount: TOKEN_PRICE});

        // withdraw
        controller.withdraw(fundsRecipient);

        // check balance
        assertEq(mockUSDC.balanceOf(fundsRecipient), fundsRecipientStartingBalance + TOKEN_PRICE);
    }

    function test__Withdraw_Fork_1() external {
        // cache starting balance
        uint256 creator0StartingBalance = mockUSDC.balanceOf(users.creator_0);
        uint256 creator1StartingBalance = mockUSDC.balanceOf(users.creator_1);

        // create fork
        (RouxEdition forkEdition, uint256 tokenId) = _createFork(edition, 1, users.creator_1);

        // approve fork
        _approveToken(address(forkEdition), testMinter);

        // compute split
        (uint256 parentShare, uint256 childShare) = _computeSplit(edition, tokenId, TOKEN_PRICE);

        // mint
        _mintToken(forkEdition, tokenId, testMinter);

        // disburse pending from original edition
        controller.disbursePending(address(edition), tokenId);

        // get funds recipient
        address fundsRecipient = controller.fundsRecipient(address(edition), 1);

        // check balances
        assertEq(controller.pending(address(edition), 1), 0);
        assertEq(controller.balance(fundsRecipient), parentShare);

        // withdraw - fork
        vm.prank(users.creator_1);
        controller.withdraw(controller.fundsRecipient(address(forkEdition), 1));

        // withdraw - original
        vm.prank(users.creator_0);
        controller.withdraw(controller.fundsRecipient(address(edition), 1));

        // check balances
        assertEq(mockUSDC.balanceOf(address(users.creator_0)), creator0StartingBalance + parentShare);
        assertEq(mockUSDC.balanceOf(address(users.creator_1)), creator1StartingBalance + childShare);
    }

    function test__DisbursePendingAndWithdraw_Fork_1() external {
        // cache starting balance
        uint256 creator0StartingBalance = mockUSDC.balanceOf(users.creator_0);

        // create fork
        (RouxEdition forkEdition, uint256 tokenId) = _createFork(edition, 1, users.creator_1);

        // approve fork
        _approveToken(address(forkEdition), testMinter);

        // compute split
        (uint256 parentShare,) = _computeSplit(edition, tokenId, TOKEN_PRICE);

        // mint
        _mintToken(forkEdition, tokenId, testMinter);

        // call disburse pending and withdraw
        controller.disbursePendingAndWithdraw(address(edition), tokenId);

        // get funds recipient
        address fundsRecipient = controller.fundsRecipient(address(edition), 1);

        // check balances
        assertEq(controller.pending(address(edition), 1), 0);
        assertEq(controller.balance(fundsRecipient), 0);

        // check balances
        assertEq(mockUSDC.balanceOf(users.creator_0), creator0StartingBalance + parentShare);
    }

    function test__DisbursePendingAndWithdraw_Fork_2() external {
        _disbursePendingAndWithdraw(2);
    }

    function test__DisbursePendingAndWithdraw_Fork_3() external {
        _disbursePendingAndWithdraw(3);
    }

    function test__DisbursePendingAndWithdraw_Fork_4() external {
        _disbursePendingAndWithdraw(4);
    }

    function test__DisbursePendingAndWithdraw_Fork_5() external {
        _disbursePendingAndWithdraw(5);
    }

    function test__DisbursePendingAndWithdraw_Fork_6() external {
        _disbursePendingAndWithdraw(6);
    }

    function test__DisbursePendingAndWithdraw_Fork_7() external {
        _disbursePendingAndWithdraw(7);
    }

    function test__DisbursePendingAndWithdraw_Fork_8() external {
        _disbursePendingAndWithdraw(8);
    }

    function test__PlatformFee_RecordedOnMint() external {
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(controller) });
        emit PlatformFeeUpdated({ enabled: true });

        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        // mint
        _mintToken(edition, 1, testMinter);

        // check balance
        assertEq(controller.platformFeeBalance(), (TOKEN_PRICE * controller.PLATFORM_FEE()) / 10_000);
    }

    function test__DisablePlatformFee() external {
        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        // mint
        _mintToken(edition, 1, testMinter);

        // check balance
        assertEq(controller.platformFeeBalance(), (TOKEN_PRICE * controller.PLATFORM_FEE()) / 10_000);

        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(controller) });
        emit PlatformFeeUpdated({ enabled: false });

        // disable
        vm.prank(users.deployer);
        controller.enablePlatformFee(false);
    }

    function test__WithdrawPlatformFee() external {
        // cache deployer starting balance
        uint256 startingBalance = mockUSDC.balanceOf(users.deployer);

        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        // mint
        _mintToken(edition, 1, testMinter);

        // expected admin fee
        uint256 expectedPlatformFee = (TOKEN_PRICE * controller.PLATFORM_FEE()) / 10_000;

        // check balance
        assertEq(controller.platformFeeBalance(), expectedPlatformFee);

        // withdraw
        vm.prank(users.deployer);
        controller.withdrawPlatformFee(users.deployer);

        // check balance
        assertEq(controller.platformFeeBalance(), 0);

        // check deployer balance
        assertEq(mockUSDC.balanceOf(users.deployer), startingBalance + expectedPlatformFee);
    }

    /* -------------------------------------------- */
    /* utility                                      */
    /* -------------------------------------------- */

    function _getRecipientIndex(address recipient, address[] memory recipientArray) internal pure returns (uint256) {
        uint256 recipientIndex = type(uint256).max;
        for (uint256 j = 0; j < recipientArray.length; j++) {
            if (recipientArray[j] == recipient) {
                recipientIndex = j;
                break;
            }
        }
        if (recipientIndex == type(uint256).max) revert("Recipient not found in creatorArray");
        return recipientIndex;
    }

    function _disburse_pending(uint256 numForks) internal {
        // create forks
        RouxEdition[] memory editions = _createForks(numForks);

        // validate length
        assertEq(editions.length, numForks + 1, "length should be numForks + 1");

        // approve last fork
        _approveToken(address(editions[editions.length - 1]), testMinter);

        // create running balances array
        uint256[] memory runningBalances = new uint256[](creatorArray.length);

        // mint last fork
        _mintToken(editions[editions.length - 1], 1, testMinter);

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
                controller.disbursePending(address(editions[i]), 1);

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
                        string(abi.encodePacked("balance after disburse incorrect for edition ", Strings.toString(i)))
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

    function _disbursePendingAndWithdraw(uint256 numForks) internal {
        // create forks
        RouxEdition[] memory editions = _createForks(numForks);

        // validate length
        assertEq(editions.length, numForks + 1, "length should be numForks + 1");

        // approve last fork
        _approveToken(address(editions[editions.length - 1]), testMinter);

        // create running withdrawal amounts array
        uint256[] memory runningWithdrawals = new uint256[](creatorArray.length);

        // store initial balances
        uint256[] memory initialBalances = new uint256[](creatorArray.length);
        for (uint256 i = 0; i < creatorArray.length; i++) {
            initialBalances[i] = mockUSDC.balanceOf(creatorArray[i]);
        }

        // mint last fork
        _mintToken(editions[editions.length - 1], 1, testMinter);

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
            if (recipientIndex == type(uint256).max) revert("Recipient not found in creatorArray");

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
                controller.disbursePendingAndWithdraw(address(editions[i]), 1);

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
                        string(abi.encodePacked("withdrawal incorrect for edition ", Strings.toString(i)))
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
