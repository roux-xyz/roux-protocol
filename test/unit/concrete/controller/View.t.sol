// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";

contract View_Controller_Unit_Concrete_Test is BaseTest {
    EditionData.AddParams addParams;

    function setUp() public override {
        BaseTest.setUp();

        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /// @dev returns correct owner
    function test__Owner() external view {
        assertEq(controller.owner(), users.deployer);
    }

    /// @dev returns correct currency address
    function test__Currency() external view {
        assertEq(controller.currency(), address(mockUSDC));
    }

    /// @dev returns correct decimals
    function test__Decimals() external view {
        assertEq(controller.decimals(), 6);
    }

    /// @dev returns correct balance
    function test__Balance() external view {
        assertEq(controller.balance(users.user_0), 0);
    }

    /// @dev returns correct balance - after recording funds
    function test__Balance_AfterRecordFunds() external {
        // record funds
        vm.prank(user);
        mockUSDC.approve(address(controller), type(uint256).max);

        vm.prank(user);
        controller.recordFunds(users.user_0, TOKEN_PRICE);

        assertEq(controller.balance(users.user_0), TOKEN_PRICE);
    }

    /// @dev returns correct pending balance
    function test__Pending() external view {
        assertEq(controller.pending(address(edition), 1), 0);
    }

    /// @dev returns correct platform fee balance
    function test__PlatformFeeBalance() external view {
        assertEq(controller.platformFeeBalance(), 0);
    }

    /// @dev returns correct profit share
    function test__ProfitShare() external view {
        assertEq(controller.profitShare(address(edition), 1), PROFIT_SHARE);
    }

    /// @dev returns correct funds recipient
    function test__FundsRecipient() external view {
        assertEq(controller.fundsRecipient(address(edition), 1), creator);
    }

    /// @dev returns correct platform fee enabled
    function test__PlatformFeeEnabled() external view {
        assertEq(controller.platformFeeEnabled(), false);
    }

    /// @dev returns correct platform fee enabled status after platform fee is enabled
    function test__PlatformFeeEnabled_True() external {
        // enable platform fee
        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        assertEq(controller.platformFeeEnabled(), true);
    }
}
