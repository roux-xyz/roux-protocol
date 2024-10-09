// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { ControllerBase } from "test/shared/ControllerBase.t.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { Initializable } from "solady/utils/Initializable.sol";

contract Admin_Controller_Integration_Concrete_Test is ControllerBase {
    function setUp() public override {
        ControllerBase.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    function test__RevertWhen_EnablePlatformFee_OnlyOwner() external {
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.enablePlatformFee(true);
    }

    function test__RevertWhen_UpgradeToAndCall_OnlyOwner() external {
        vm.prank(creator);
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.upgradeToAndCall(address(edition), "");
    }

    function test__RevertWhen_AlreadyInitialized() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        controller.initialize();
    }

    /* -------------------------------------------- */
    /* writes                                       */
    /* -------------------------------------------- */

    function test__PlatformFee_RecordedOnMint() external {
        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.PlatformFeeUpdated({ enabled: true });

        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        _mintToken(edition, 1, user);

        assertEq(controller.platformFeeBalance(), (TOKEN_PRICE * PLATFORM_FEE) / 10_000);
    }

    function test__DisablePlatformFee() external {
        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        _mintToken(edition, 1, user);

        assertEq(controller.platformFeeBalance(), (TOKEN_PRICE * PLATFORM_FEE) / 10_000);

        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.PlatformFeeUpdated({ enabled: false });

        vm.prank(users.deployer);
        controller.enablePlatformFee(false);
    }

    function test__WithdrawPlatformFee() external {
        uint256 startingBalance = mockUSDC.balanceOf(users.deployer);

        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        _mintToken(edition, 1, user);

        uint256 expectedPlatformFee = (TOKEN_PRICE * PLATFORM_FEE) / 10_000;

        assertEq(controller.platformFeeBalance(), expectedPlatformFee);

        vm.prank(users.deployer);
        controller.withdrawPlatformFee(users.deployer);

        assertEq(controller.platformFeeBalance(), 0);
        assertEq(mockUSDC.balanceOf(users.deployer), startingBalance + expectedPlatformFee);
    }
}
