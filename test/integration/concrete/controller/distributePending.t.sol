// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

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

    /// @dev distribute pending for single fork
    function test__DistributePending_Fork_1() external {
        // create fork
        (RouxEdition forkEdition, uint256 tokenId) = _createFork(edition, 1, users.creator_1);

        // approve fork
        _approveToken(address(forkEdition), user);

        // compute split
        (uint256 parentShare,) = _computeSplit(edition, tokenId, TOKEN_PRICE);

        // mint
        _mintToken(forkEdition, tokenId, user);

        // expect emit
        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.PendingDistributed({ edition: address(edition), tokenId: 1, amount: parentShare });

        // disburse pending from original edition
        controller.distributePending(address(edition), tokenId);

        // get funds recipient
        address fundsRecipient = controller.fundsRecipient(address(edition), 1);

        // check balances
        assertEq(controller.pending(address(edition), 1), 0);
        assertEq(controller.balance(fundsRecipient), parentShare);
    }

    /// @dev distribute pending for two forks
    function test__DistributePending_Fork_2() external {
        _test__distributePending(2);
    }

    /// @dev distribute pending for three forks
    function test__DistributePending_Fork_3() external {
        _test__distributePending(3);
    }

    /// @dev distribute pending for eight forks
    function test__DistributePending_Fork_8() external {
        _test__distributePending(8);
    }

    /// @dev distribute pending with hardcoded values
    function test__DistributePending_Hardcoded() public {
        uint256 PRICE = 2 * 10 ** 6;
        RouxEdition root = edition;

        // Create Fork1 with a specific default price and profit share
        EditionData.AddParams memory fork1Params = defaultAddParams;
        fork1Params.defaultPrice = PRICE;
        fork1Params.fundsRecipient = users.creator_1;
        fork1Params.parentEdition = address(root);
        fork1Params.parentTokenId = 1;
        fork1Params.profitShare = 3_000;

        RouxEdition fork1 = _createEdition(users.creator_1);

        vm.prank(users.creator_1);
        uint256 fork1TokenId = fork1.add(fork1Params);

        // Create Fork2 with the same default price and a different profit share
        EditionData.AddParams memory fork2Params = fork1Params;
        fork2Params.fundsRecipient = users.creator_2;
        fork2Params.parentEdition = address(fork1);
        fork2Params.parentTokenId = fork1TokenId;
        fork2Params.profitShare = 4_000;

        RouxEdition fork2 = _createEdition(users.creator_2);

        vm.prank(users.creator_2);
        uint256 fork2TokenId = fork2.add(fork2Params);

        // Mint a token on Fork2
        vm.prank(user);
        mockUSDC.approve(address(fork2), PRICE);

        vm.prank(user);
        fork2.mint(user, fork2TokenId, 1, address(0), address(0), "");

        // Calculate expected distributions
        uint256 fork2Share = PRICE * 3_000 / 10000; // 30% of 100 USDC
        uint256 fork1Share = (PRICE - fork2Share) * 4_000 / 10000; // 30% of remaining
        uint256 rootShare = PRICE - fork2Share - fork1Share;

        // Distribute pending funds
        controller.distributePending(address(fork2), fork2TokenId);
        controller.distributePending(address(fork1), fork1TokenId);
        controller.distributePending(address(root), 1);

        // Verify balances
        assertEq(controller.balance(users.creator_2), fork2Share);
        assertEq(controller.balance(users.creator_1), fork1Share);
        assertEq(controller.balance(creator), rootShare);

        // Verify pending amounts are zero
        assertEq(controller.pending(address(fork2), fork2TokenId), 0);
        assertEq(controller.pending(address(fork1), fork1TokenId), 0);
        assertEq(controller.pending(address(root), 1), 0);
    }
}
