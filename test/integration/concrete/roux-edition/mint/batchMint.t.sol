// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IExtension } from "src/interfaces/IExtension.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { MockExtension } from "test/mocks/MockExtension.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

contract BatchMint_RouxEdition_Integration_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    EditionData.AddParams addParams;
    uint256[] ids;
    uint256[] quantities;
    address[] extensions;

    function setUp() public override {
        BaseTest.setUp();

        addParams = defaultAddParams;

        // Add multiple tokens
        for (uint256 i = 0; i < 3; i++) {
            _addToken(edition);
        }

        ids = [1, 2, 3];
        quantities = [1, 2, 1];
        extensions = new address[](3);
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev extension reverts call to approve mint
    function test__RevertWhen_Extension_ApproveMint_Reverts() external {
        address to = address(0x12345678);

        vm.startPrank(creator);
        edition.setExtension(1, address(mockExtension), true, "");
        edition.setExtension(2, address(mockExtension), true, "");
        edition.setExtension(3, address(mockExtension), true, "");
        vm.stopPrank();

        extensions[0] = address(mockExtension);
        extensions[1] = address(mockExtension);
        extensions[2] = address(mockExtension);

        vm.prank(user);
        vm.expectRevert(MockExtension.InvalidAccount.selector);
        edition.batchMint(to, ids, quantities, extensions, user, "");
    }

    /// @dev revert when arrays have different lengths
    function test__RevertWhen_ArrayLengthsMismatch() external {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidParams.selector);
        edition.batchMint(user, ids, new uint256[](2), extensions, user, "");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    // @dev batch mint with platform fee
    function test__BatchMint_WithPlatformFee() external {
        uint256 startingUserBalance = mockUSDC.balanceOf(user);
        uint256 startingCreatorControllerBalance = _getUserControllerBalance(creator);
        uint256 startingPlatformFeeBalance = controller.platformFeeBalance();

        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        uint256 totalPrice = TOKEN_PRICE * 4;
        uint256 platformFee = (totalPrice * PLATFORM_FEE) / 10_000;

        vm.prank(user);
        edition.batchMint(user, ids, quantities, extensions, address(0), "");

        assertEq(mockUSDC.balanceOf(user), startingUserBalance - totalPrice);
        assertEq(_getUserControllerBalance(creator), startingCreatorControllerBalance + totalPrice - platformFee);
        assertEq(controller.platformFeeBalance(), startingPlatformFeeBalance + platformFee);
    }

    /// @dev batch mint with referral
    function test__BatchMint_WithReferral() external {
        uint256 startingUserBalance = mockUSDC.balanceOf(user);
        uint256 startingCreatorControllerBalance = _getUserControllerBalance(creator);
        uint256 startingReferralControllerBalance = _getUserControllerBalance(users.user_1);

        uint256 totalPrice = TOKEN_PRICE * 4; // 1 + 2 + 1
        uint256 referralFee = (totalPrice * REFERRAL_FEE) / 10_000;

        vm.prank(user);
        edition.batchMint(user, ids, quantities, extensions, users.user_1, "");

        assertEq(mockUSDC.balanceOf(user), startingUserBalance - totalPrice);
        assertEq(_getUserControllerBalance(creator), startingCreatorControllerBalance + totalPrice - referralFee);
        assertEq(_getUserControllerBalance(users.user_1), startingReferralControllerBalance + referralFee);
    }

    /// @dev batch mint - platform fee + referral fee
    function test__BatchMint_WithPlatformFeeAndReferral() external {
        uint256 startingUserBalance = mockUSDC.balanceOf(user);
        uint256 startingCreatorControllerBalance = _getUserControllerBalance(creator);
        uint256 startingReferralControllerBalance = _getUserControllerBalance(users.user_1);
        uint256 startingPlatformFeeBalance = controller.platformFeeBalance();

        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        uint256 totalPrice = TOKEN_PRICE * 4; // 1 + 2 + 1
        uint256 platformFee = (totalPrice * PLATFORM_FEE) / 10_000;
        uint256 referralFee = (totalPrice * REFERRAL_FEE) / 10_000;

        vm.prank(user);
        edition.batchMint(user, ids, quantities, extensions, users.user_1, "");

        assertEq(mockUSDC.balanceOf(user), startingUserBalance - totalPrice);
        assertEq(
            _getUserControllerBalance(creator),
            startingCreatorControllerBalance + totalPrice - platformFee - referralFee
        );
        assertEq(controller.platformFeeBalance(), startingPlatformFeeBalance + platformFee);
        assertEq(_getUserControllerBalance(users.user_1), startingReferralControllerBalance + referralFee);
    }

    /// @dev batch mint - balances should be correctly updated
    function test__BatchMint_WithoutExtension_BalancesUpdated() external {
        uint256 startingBalance = mockUSDC.balanceOf(user);

        vm.prank(user);
        edition.batchMint(user, ids, quantities, extensions, user, "");

        assertEq(edition.balanceOf(user, 1), 1);
        assertEq(edition.balanceOf(user, 2), 2);
        assertEq(edition.balanceOf(user, 3), 1);
        assertEq(edition.totalSupply(1), 2);
        assertEq(edition.totalSupply(2), 3);
        assertEq(edition.totalSupply(3), 2);

        assertEq(mockUSDC.balanceOf(user), startingBalance - (TOKEN_PRICE * 4));
    }

    /// @dev batch mint with extension
    function test__BatchMint_WithExtension_CustomMintParams() external {
        uint128 customPrice = 5 * 10 ** 5;
        uint256 startingBalance = mockUSDC.balanceOf(user);

        vm.startPrank(creator);
        edition.setExtension(1, address(mockExtension), true, abi.encode(customPrice));
        edition.setExtension(2, address(mockExtension), true, abi.encode(customPrice));
        edition.setExtension(3, address(mockExtension), true, abi.encode(customPrice));
        vm.stopPrank();

        extensions[0] = address(mockExtension);
        extensions[1] = address(mockExtension);
        extensions[2] = address(mockExtension);

        vm.prank(user);
        edition.batchMint(user, ids, quantities, extensions, user, "");

        assertEq(edition.balanceOf(user, 1), 1);
        assertEq(edition.balanceOf(user, 2), 2);
        assertEq(edition.balanceOf(user, 3), 1);
        assertEq(edition.totalSupply(1), 2);
        assertEq(edition.totalSupply(2), 3);
        assertEq(edition.totalSupply(3), 2);

        assertEq(mockUSDC.balanceOf(user), startingBalance - (customPrice * 4)); // 1 + 2 + 1
    }

    /// @dev batch mint with mixed extensions and non-extensions
    function test__BatchMint_MixedExtensions() external {
        uint128 customPrice = 5 * 10 ** 5;
        uint256 startingBalance = mockUSDC.balanceOf(user);

        vm.prank(creator);
        edition.setExtension(2, address(mockExtension), true, abi.encode(customPrice));

        extensions[1] = address(mockExtension);

        vm.prank(user);
        edition.batchMint(user, ids, quantities, extensions, user, "");

        assertEq(edition.balanceOf(user, 1), 1);
        assertEq(edition.balanceOf(user, 2), 2);
        assertEq(edition.balanceOf(user, 3), 1);
        assertEq(edition.totalSupply(1), 2);
        assertEq(edition.totalSupply(2), 3);
        assertEq(edition.totalSupply(3), 2);

        uint256 expectedCost = TOKEN_PRICE + (customPrice * 2) + TOKEN_PRICE;
        assertEq(mockUSDC.balanceOf(user), startingBalance - expectedCost);
    }
}
