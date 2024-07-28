// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IController } from "src/interfaces/IController.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { BaseTest } from "./Base.t.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { EditionData } from "src/types/DataTypes.sol";

import { EventsLib } from "src/libraries/EventsLib.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/console.sol";

contract ControllerTest is BaseTest {
    address testMinter;

    function setUp() public virtual override {
        BaseTest.setUp();

        // set test edition minter
        testMinter = address(user);

        // approve test edition to spend mock usdc
        _approveToken(address(edition), testMinter);
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    function test__RevertWhen_SetController_FundsRecipientIsZero() external {
        defaultAddParams.fundsRecipient = address(0);

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.Controller_InvalidFundsRecipient.selector);
        edition.add(defaultAddParams);
    }

    function test__RevertWhen_SetController_ProfitShareTooHigh() external {
        RouxEdition edition_ = _createEdition(creator);

        defaultAddParams.profitShare = 10_001;
        defaultAddParams.parentEdition = address(edition);
        defaultAddParams.parentTokenId = 1;

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.Controller_InvalidProfitShare.selector);
        edition_.add(defaultAddParams);
    }

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

    function test__AddToken_SetControllerData() external {
        (, uint256 tokenId) = _addToken(edition);

        assertEq(tokenId, 2);
        assertEq(controller.fundsRecipient(address(edition), tokenId), defaultAddParams.fundsRecipient);
        assertEq(controller.profitShare(address(edition), tokenId), PROFIT_SHARE);
    }

    function test__PlatformFee_RecordedOnMint() external {
        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.PlatformFeeUpdated({ enabled: true });

        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        _mintToken(edition, 1, testMinter);

        assertEq(controller.platformFeeBalance(), (TOKEN_PRICE * PLATFORM_FEE) / 10_000);
    }

    function test__DisablePlatformFee() external {
        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        _mintToken(edition, 1, testMinter);

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

        _mintToken(edition, 1, testMinter);

        uint256 expectedPlatformFee = (TOKEN_PRICE * PLATFORM_FEE) / 10_000;

        assertEq(controller.platformFeeBalance(), expectedPlatformFee);

        vm.prank(users.deployer);
        controller.withdrawPlatformFee(users.deployer);

        assertEq(controller.platformFeeBalance(), 0);
        assertEq(mockUSDC.balanceOf(users.deployer), startingBalance + expectedPlatformFee);
    }
}
