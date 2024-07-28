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

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when disburse called on token without funds recipient
    function test__RevertWhen_Disburse_TokenWithoutFundsRecipient() external {
        // approve
        vm.prank(user);
        mockUSDC.approve(address(controller), type(uint256).max);

        // disburse
        vm.prank(user);
        vm.expectRevert(ErrorsLib.Controller_InvalidFundsRecipient.selector);
        controller.disburse({ id: 1, amount: TOKEN_PRICE, referrer: address(0) });
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully disburses funds
    function test__Disburse_Mint() external {
        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.Deposited({ recipient: controller.fundsRecipient(address(edition), 1), amount: TOKEN_PRICE });

        _mintToken(edition, 1, user);

        assertEq(controller.balance(controller.fundsRecipient(address(edition), 1)), TOKEN_PRICE);
    }

    /// @dev successfully disburses funds on mint with referral
    function test__Disburse_Mint_Referral() external {
        uint256 referralFee = (TOKEN_PRICE * REFERRAL_FEE) / 10_000;

        vm.prank(user);
        edition.mint({ to: user, id: 1, quantity: 1, extension: address(0), referrer: user, data: "" });

        assertEq(controller.balance(controller.fundsRecipient(address(edition), 1)), TOKEN_PRICE - referralFee);
        assertEq(controller.balance(user), referralFee);
    }

    /// @dev successfully disburses funds on mint of fork
    function test__Disburse_Mint_Fork() external {
        (RouxEdition forkEdition, uint256 tokenId) = _createFork(edition, 1, users.creator_1);

        _approveToken(address(forkEdition), user);

        (uint256 parentShare, uint256 childShare) = _computeSplit(edition, tokenId, TOKEN_PRICE);

        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.Deposited({ recipient: controller.fundsRecipient(address(forkEdition), 1), amount: childShare });

        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.PendingUpdated({
            edition: address(forkEdition),
            tokenId: 1,
            parent: address(edition),
            parentTokenId: 1,
            amount: parentShare
        });

        _mintToken(forkEdition, tokenId, user);

        assertEq(controller.balance(controller.fundsRecipient(address(forkEdition), 1)), childShare);
        assertEq(controller.pending(address(edition), 1), parentShare);
    }

    /// @dev successfully disburses funds on mint of fork with referral
    function test__Disburse_Mint_Fork_Referral() external {
        // create fork
        (RouxEdition forkEdition, uint256 tokenId) = _createFork(edition, 1, users.creator_1);

        // approve fork
        _approveToken(address(forkEdition), user);

        // compute referral fee
        uint256 referralFee = (TOKEN_PRICE * REFERRAL_FEE) / 10_000;

        // mint with referral
        vm.prank(user);
        forkEdition.mint({ to: user, id: tokenId, quantity: 1, extension: address(0), referrer: users.user_1, data: "" });

        // compute split
        (uint256 parentShare, uint256 childShare) = _computeSplit(edition, tokenId, TOKEN_PRICE - referralFee);

        // check balances
        assertEq(controller.balance(controller.fundsRecipient(address(forkEdition), tokenId)), childShare);
        assertEq(controller.pending(address(edition), 1), parentShare);
        assertEq(controller.balance(users.user_1), referralFee);
    }

    function test__Mint_Fork_3() external {
        // create forks
        RouxEdition[] memory editions = _createForks(3);

        // approve fork
        _approveToken(address(editions[3]), user);

        // assert length is 4 (original + 3 forks)
        assertEq(editions.length, 4, "length should be 4");

        // mint token
        _mintToken(editions[3], 1, user);

        // get funds recipient
        address fork3fundsRecipient = controller.fundsRecipient(address(editions[3]), 1);

        // compute split
        (uint256 parentShareToFork2, uint256 childShareToFork3) = _computeSplit(editions[3], 1, TOKEN_PRICE);

        // check recipient balance
        assertEq(controller.balance(fork3fundsRecipient), childShareToFork3);

        // check pending balance
        assertEq(controller.pending(address(editions[2]), 1), parentShareToFork2);
    }
}
