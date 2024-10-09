// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxMintPortal } from "src/interfaces/IRouxMintPortal.sol";
import { Restricted1155 } from "src/abstracts/Restricted1155.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract Rescue_RouxMintPortal_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev test rescue function called by non-owner
    function test__RevertWhen_Rescue_NonOwner() external {
        uint256 excessAmount = 100 * 10 ** 6;

        // simulate excess tokens being sent directly to the contract
        vm.prank(user);
        mockUSDC.transfer(address(mintPortal), excessAmount);

        // attempt rescue by non-owner
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        mintPortal.rescue(user);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev test rescue function when there's excess underlying token
    function test__Rescue_ExcessToken() external {
        uint256 initialPortalBalance = mockUSDC.balanceOf(address(mintPortal));
        uint256 initialRecipientBalance = mockUSDC.balanceOf(users.deployer);

        uint256 excessAmount = 100 * 10 ** 6;

        // simulate excess tokens being sent directly to the contract
        vm.prank(user);
        mockUSDC.transfer(address(mintPortal), excessAmount);

        // validate balances
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalBalance + excessAmount);
        assertEq(mintPortal.totalSupply(), 0);
        assertEq(mintPortal.balanceOf(user, 1), 0);

        // perform rescue
        vm.prank(users.deployer);
        mintPortal.rescue(users.deployer);

        // check final balances
        uint256 finalPortalBalance = mockUSDC.balanceOf(address(mintPortal));
        uint256 finalRecipientBalance = mockUSDC.balanceOf(users.deployer);

        assertEq(finalPortalBalance, initialPortalBalance);
        assertEq(finalRecipientBalance, initialRecipientBalance + excessAmount);
    }

    /// @dev test rescue function when there's no excess token
    function test__Rescue_NoExcessToken() external {
        uint256 initialPortalBalance = mockUSDC.balanceOf(address(mintPortal));
        uint256 initialRecipientBalance = mockUSDC.balanceOf(users.deployer);

        uint256 depositAmount = 100 * 10 ** 6;

        // regular deposit
        vm.prank(user);
        mintPortal.deposit(user, depositAmount);

        // validate balances
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalBalance + depositAmount);
        assertEq(mintPortal.totalSupply(), depositAmount);
        assertEq(mintPortal.balanceOf(user, 1), depositAmount);

        // perform rescue
        vm.prank(users.deployer);
        mintPortal.rescue(users.deployer);

        // check final balances
        uint256 finalPortalBalance = mockUSDC.balanceOf(address(mintPortal));
        uint256 finalRecipientBalance = mockUSDC.balanceOf(users.deployer);

        assertEq(finalPortalBalance, initialPortalBalance + depositAmount);
        assertEq(finalRecipientBalance, initialRecipientBalance);
    }
}
