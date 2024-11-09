pragma solidity ^0.8.27;

import { ControllerBase } from "test/shared/ControllerBase.t.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

contract Disburse_Controller_Integration_Concrete_Test is ControllerBase {
    function setUp() public override {
        ControllerBase.setUp();
    }

    /// @dev distribute pending and withdraw for single fork
    function test__DistributePendingAndWithdraw_Fork_1() external {
        // cache starting balance
        uint256 creator0StartingBalance = mockUSDC.balanceOf(creator);

        // create fork
        (RouxEdition forkEdition, uint256 tokenId) = _createFork(edition, 1, users.creator_1);

        // approve fork
        _approveToken(address(forkEdition), user);

        // compute split
        (uint256 parentShare,) = _computeSplit(edition, tokenId, TOKEN_PRICE);

        // mint
        _mintToken(forkEdition, tokenId, user);

        // call disburse pending and withdraw
        controller.distributePendingAndWithdraw(address(edition), tokenId);

        // get funds recipient
        address fundsRecipient = controller.fundsRecipient(address(edition), 1);

        // check balances
        assertEq(controller.pending(address(edition), 1), 0);
        assertEq(controller.balance(fundsRecipient), 0);

        // check balances
        assertEq(mockUSDC.balanceOf(creator), creator0StartingBalance + parentShare);
    }

    /// @dev distribute pending and withdraw for two forks
    function test__DistributePendingAndWithdraw_Fork_2() external {
        _test__distributePendingAndWithdraw(2);
    }

    /// @dev distribute pending and withdraw for three forks
    function test__DistributePendingAndWithdraw_Fork_3() external {
        _test__distributePendingAndWithdraw(3);
    }

    /// @dev distribute pending and withdraw for eight forks
    function test__DistributePendingAndWithdraw_Fork_8() external {
        _test__distributePendingAndWithdraw(8);
    }

    /// @dev distribute pending and withdraw with hardcoded values
    function test__DistributePendingAndWithdraw_Hardcoded() public {
        uint256 PRICE = 2 * 10 ** 6;

        RouxEdition root = edition;

        // Create forks with specific default prices and profit shares
        EditionData.AddParams memory forkParams = defaultAddParams;
        forkParams.defaultPrice = PRICE;

        RouxEdition fork1 = _createEdition(users.creator_1);
        forkParams.fundsRecipient = users.creator_1;
        forkParams.parentEdition = address(root);
        forkParams.parentTokenId = 1;
        forkParams.profitShare = 2_000; // 20% profit share

        vm.prank(users.creator_1);
        uint256 fork1TokenId = fork1.add(forkParams);

        RouxEdition fork2 = _createEdition(users.creator_2);
        forkParams.fundsRecipient = users.creator_2;
        forkParams.parentEdition = address(fork1);
        forkParams.parentTokenId = fork1TokenId;
        forkParams.profitShare = 3_000; // 30% profit share

        vm.prank(users.creator_2);
        uint256 fork2TokenId = fork2.add(forkParams);

        RouxEdition fork3 = _createEdition(users.creator_3);
        forkParams.fundsRecipient = users.creator_3;
        forkParams.parentEdition = address(fork2);
        forkParams.parentTokenId = fork2TokenId;
        forkParams.profitShare = 4_000; // 40% profit share

        vm.prank(users.creator_3);
        uint256 fork3TokenId = fork3.add(forkParams);

        // Mint a token on Fork3
        vm.prank(user);
        mockUSDC.approve(address(fork3), PRICE);

        vm.prank(user);
        fork3.mint(user, fork3TokenId, 1, address(0), address(0), "");

        // Calculate expected distributions
        uint256 fork3Share = PRICE * 3_000 / 10000;
        uint256 fork2Share = (PRICE - fork3Share) * 2_000 / 10000;
        uint256 fork1Share = (PRICE - fork3Share - fork2Share) * 4_000 / 10000;
        uint256 rootShare = PRICE - fork3Share - fork2Share - fork1Share;

        // Store initial USDC balances
        uint256 initialFork3Balance = mockUSDC.balanceOf(users.creator_3);
        uint256 initialFork2Balance = mockUSDC.balanceOf(users.creator_2);
        uint256 initialFork1Balance = mockUSDC.balanceOf(users.creator_1);
        uint256 initialRootBalance = mockUSDC.balanceOf(creator);

        // Distribute pending funds and withdraw
        controller.distributePendingAndWithdraw(address(fork3), fork3TokenId);
        controller.distributePendingAndWithdraw(address(fork2), fork2TokenId);
        controller.distributePendingAndWithdraw(address(fork1), fork1TokenId);
        controller.distributePendingAndWithdraw(address(root), 1);

        // Verify USDC balances have increased correctly
        assertEq(mockUSDC.balanceOf(users.creator_3) - initialFork3Balance, fork3Share);
        assertEq(mockUSDC.balanceOf(users.creator_2) - initialFork2Balance, fork2Share);
        assertEq(mockUSDC.balanceOf(users.creator_1) - initialFork1Balance, fork1Share);
        assertEq(mockUSDC.balanceOf(creator) - initialRootBalance, rootShare);

        // Verify pending amounts and controller balances are zero
        assertEq(controller.pending(address(fork3), fork3TokenId), 0);
        assertEq(controller.pending(address(fork2), fork2TokenId), 0);
        assertEq(controller.pending(address(fork1), fork1TokenId), 0);
        assertEq(controller.pending(address(root), 1), 0);

        assertEq(controller.balance(users.creator_3), 0, "Fork3 controller balance should be 0");
        assertEq(controller.balance(users.creator_2), 0, "Fork2 controller balance should be 0");
        assertEq(controller.balance(users.creator_1), 0, "Fork1 controller balance should be 0");
        assertEq(controller.balance(creator), 0, "Root controller balance should be 0");
    }
}
