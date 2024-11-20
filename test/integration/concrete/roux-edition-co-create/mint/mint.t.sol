// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { IExtension } from "src/periphery/interfaces/IExtension.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { MockExtension } from "test/mocks/MockExtension.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

contract Mint_RouxEditionCoCreate_Integration_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    EditionData.AddParams addParams;

    function setUp() public override {
        BaseTest.setUp();

        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev extension reverts call to approve mint
    function test__RevertWhen_Extension_ApproveMint_Reverts() external {
        address to = address(0x12345678);

        vm.prank(creator);
        coCreateEdition.setExtension(1, address(mockExtension), true, "");

        vm.prank(user);
        vm.expectRevert(MockExtension.InvalidAccount.selector);
        coCreateEdition.mint({ to: to, id: 1, quantity: 1, extension: address(mockExtension), referrer: user, data: "" });
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    // @dev mint with platform fee
    function test__Mint_WithPlatformFee() external {
        // cache starting user balance
        uint256 startingUserBalance = mockUSDC.balanceOf(user);
        uint256 startingCreatorControllerBalance = _getUserControllerBalance(creator);
        uint256 startingPlatformFeeBalance = controller.platformFeeBalance();

        // enable platform fee
        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        // calculate platform fee
        uint256 platformFee = (TOKEN_PRICE * PLATFORM_FEE) / 10_000;

        // mint
        vm.prank(user);
        coCreateEdition.mint(user, 1, 1, address(0), address(0), "");

        // verify user balance
        assertEq(mockUSDC.balanceOf(user), startingUserBalance - addParams.defaultPrice);
        assertEq(
            _getUserControllerBalance(creator), startingCreatorControllerBalance + addParams.defaultPrice - platformFee
        );
        assertEq(controller.platformFeeBalance(), startingPlatformFeeBalance + platformFee);
    }

    /// @dev mints token with referral
    function test__Mint_WithReferral() external {
        // cache starting user balance
        uint256 startingUserBalance = mockUSDC.balanceOf(user);
        uint256 startingCreatorControllerBalance = _getUserControllerBalance(creator);
        uint256 startingCreatorControllerBalanceReferral = _getUserControllerBalance(users.user_1);

        // calculate referral fee
        uint256 referralFee = (TOKEN_PRICE * REFERRAL_FEE) / 10_000;

        vm.prank(user);
        coCreateEdition.mint({ to: user, id: 1, quantity: 1, extension: address(0), referrer: users.user_1, data: "" });

        assertEq(coCreateEdition.balanceOf(user, 1), 1);
        assertEq(coCreateEdition.totalSupply(1), 2);

        // verify user balance
        assertEq(mockUSDC.balanceOf(user), startingUserBalance - addParams.defaultPrice);
        assertEq(
            _getUserControllerBalance(creator), startingCreatorControllerBalance + addParams.defaultPrice - referralFee
        );
        assertEq(_getUserControllerBalance(users.user_1), startingCreatorControllerBalanceReferral + referralFee);
    }

    /// @dev mint - platform fee + referral fee
    function test__Mint_WithPlatformFeeAndReferral() external {
        // cache starting user balance
        uint256 startingUserBalance = mockUSDC.balanceOf(user);
        uint256 startingCreatorControllerBalance = _getUserControllerBalance(creator);
        uint256 startingCreatorControllerBalanceReferral = _getUserControllerBalance(users.user_1);
        uint256 startingPlatformFeeBalance = controller.platformFeeBalance();

        // enable platform fee
        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        // calculate platform fee
        uint256 platformFee = (TOKEN_PRICE * PLATFORM_FEE) / 10_000;

        // calculate referral fee
        uint256 referralFee = (TOKEN_PRICE * REFERRAL_FEE) / 10_000;

        vm.prank(user);
        coCreateEdition.mint({ to: user, id: 1, quantity: 1, extension: address(0), referrer: users.user_1, data: "" });

        assertEq(coCreateEdition.balanceOf(user, 1), 1);
        assertEq(coCreateEdition.totalSupply(1), 2);

        // verify balances
        assertEq(mockUSDC.balanceOf(user), startingUserBalance - addParams.defaultPrice);
        assertEq(
            _getUserControllerBalance(creator),
            startingCreatorControllerBalance + addParams.defaultPrice - platformFee - referralFee
        );
        assertEq(controller.platformFeeBalance(), startingPlatformFeeBalance + platformFee);
        assertEq(_getUserControllerBalance(users.user_1), startingCreatorControllerBalanceReferral + referralFee);
    }

    /// @dev mint - balances should be correctly updated
    function test__Mint_WithoutExtension_BalancesUpdated() external {
        uint256 startingBalance = mockUSDC.balanceOf(user);

        vm.expectEmit({ emitter: address(coCreateEdition) });
        emit TransferSingle({ operator: user, from: address(0), to: user, id: 1, amount: 1 });

        vm.prank(user);
        coCreateEdition.mint({ to: user, id: 1, quantity: 1, extension: address(0), referrer: user, data: "" });

        assertEq(coCreateEdition.balanceOf(user, 1), 1);
        assertEq(coCreateEdition.totalSupply(1), 2);

        assertEq(mockUSDC.balanceOf(user), startingBalance - addParams.defaultPrice);
    }

    /// @dev mint with extension
    function test__Mint_WithExtension_BalancesUnchanged() external {
        uint256 startingBalance = mockUSDC.balanceOf(user);

        vm.prank(creator);
        coCreateEdition.setExtension(1, address(mockExtension), true, "");

        vm.expectEmit({ emitter: address(coCreateEdition) });
        emit TransferSingle({ operator: user, from: address(0), to: user, id: 1, amount: 1 });

        vm.prank(user);
        coCreateEdition.mint({
            to: user,
            id: 1,
            quantity: 1,
            extension: address(mockExtension),
            referrer: user,
            data: ""
        });

        assertEq(coCreateEdition.balanceOf(user, 1), 1);
        assertEq(coCreateEdition.totalSupply(1), 2);

        assertEq(mockUSDC.balanceOf(user), startingBalance);
    }

    /// @dev mint with extension - custom mint params with different price
    function test__Mint_WithExtension_CustomMintParams() external {
        uint128 customPrice = 5 * 10 ** 5;

        uint256 startingBalance = mockUSDC.balanceOf(user);

        vm.prank(creator);
        coCreateEdition.setExtension(1, address(mockExtension), true, abi.encode(customPrice));

        vm.prank(user);
        coCreateEdition.mint({
            to: user,
            id: 1,
            quantity: 1,
            extension: address(mockExtension),
            referrer: user,
            data: ""
        });

        assertEq(coCreateEdition.balanceOf(user, 1), 1);
        assertEq(coCreateEdition.totalSupply(1), 2);

        assertEq(mockUSDC.balanceOf(user), startingBalance - customPrice);
    }

    /// @dev mint gated mint with extension
    function test__Mint_WithExtension_GatedMint() external {
        uint128 customPrice = 5 * 10 ** 5;
        uint256 startingBalance = mockUSDC.balanceOf(user);

        // gate token on add
        addParams.gate = true;

        // create coCreateEdition instance
        RouxEdition coCreateEdition_ = _createEdition(users.creator_1);

        vm.startPrank(users.creator_1);
        coCreateEdition_.add(addParams);
        coCreateEdition_.setExtension(1, address(mockExtension), true, abi.encode(customPrice));
        vm.stopPrank();

        // verify gate is set
        assertEq(coCreateEdition_.isGated(1), true);

        // approve coCreateEdition
        vm.startPrank(user);
        mockUSDC.approve(address(coCreateEdition_), type(uint256).max);

        // mint
        coCreateEdition_.mint({
            to: user,
            id: 1,
            quantity: 1,
            extension: address(mockExtension),
            referrer: user,
            data: ""
        });
        vm.stopPrank();

        assertEq(coCreateEdition_.balanceOf(user, 1), 1);
        assertEq(coCreateEdition_.totalSupply(1), 2);

        assertEq(mockUSDC.balanceOf(user), startingBalance - customPrice);
    }
}
