// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxMintPortal } from "src/interfaces/IRouxMintPortal.sol";

contract Deposit_RouxMintPortal_Unit_Fuzz_Test is BaseTest {
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
    function test_Fuzz__Deposit(uint256 depositAmount) external {
        depositAmount = bound(depositAmount, 0, type(uint224).max);
        mockUSDC.mint(user, depositAmount);

        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));
        uint256 initialUserUSDCBalance = mockUSDC.balanceOf(user);

        uint256 initialPortalSupply = mintPortal.totalSupply();
        uint256 inititalRUSDCBalance = mintPortal.balanceOf(user, 1);

        vm.prank(user);
        mockUSDC.approve(address(mintPortal), depositAmount);

        vm.prank(user);
        mintPortal.deposit(user, depositAmount);

        assertEq(mintPortal.totalSupply(), initialPortalSupply + depositAmount);
        assertEq(mintPortal.balanceOf(user, 1), inititalRUSDCBalance + depositAmount);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance + depositAmount);
        assertEq(mockUSDC.balanceOf(user), initialUserUSDCBalance - depositAmount);
    }
}
