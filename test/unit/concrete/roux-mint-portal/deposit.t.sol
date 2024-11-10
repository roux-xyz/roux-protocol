// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { IRouxMintPortal } from "src/periphery/interfaces/IRouxMintPortal.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract Deposit_RouxMintPortal_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev deposit
    function test__Deposit() external {
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));
        uint256 initialUserUSDCBalance = mockUSDC.balanceOf(user);

        uint256 initialPortalSupply = mintPortal.totalSupply();
        uint256 inititalRUSDCBalance = mintPortal.balanceOf(user, 1);

        uint256 depositAmount = 100 * 10 ** 6;

        vm.prank(user);
        mintPortal.deposit(user, depositAmount);

        assertEq(mintPortal.totalSupply(), initialPortalSupply + depositAmount);
        assertEq(mintPortal.balanceOf(user, 1), inititalRUSDCBalance + depositAmount);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance + depositAmount);
        assertEq(mockUSDC.balanceOf(user), initialUserUSDCBalance - depositAmount);
    }

    function test__Deposit_EmitsEvent() external {
        uint256 depositAmount = 100 * 10 ** 6;

        vm.prank(user);
        vm.expectEmit({ emitter: address(mintPortal) });
        emit EventsLib.Deposit(user, 1, depositAmount);
        mintPortal.deposit(user, depositAmount);
    }
}
