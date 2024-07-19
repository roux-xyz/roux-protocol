// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";

import { Ownable } from "solady/auth/Ownable.sol";

import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IEditionExtension } from "src/interfaces/IEditionExtension.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";

import { MockExtension } from "test/mocks/MockExtension.sol";

contract Mint_RouxEdition_Integration_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    EditionData.AddParams addParams;

    function setUp() public override {
        BaseTest.setUp();

        // copy default add params
        addParams = defaultAddParams;

        // approve token
        vm.prank(users.user_0);
        mockUSDC.approve(address(edition), type(uint256).max);

        // approve token - user_1
        vm.prank(users.user_1);
        mockUSDC.approve(address(edition), type(uint256).max);
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev extension reverts call to approve mint
    function test__RevertWhen_Extension_ApproveMint_Reverts() external {
        address to = address(0x12345678);

        // set extension
        vm.prank(users.creator_0);
        edition.setExtension(1, address(mockExtension), true, "");

        // mint token
        vm.prank(users.user_0);
        vm.expectRevert(MockExtension.InvalidAccount.selector);
        edition.mint({ to: to, id: 1, quantity: 1, extension: address(mockExtension), referrer: users.user_0, data: "" });
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    // @dev mint - balances should be correctly updated
    function test__Mint_WithoutExtension_BalancesUpdated() external {
        // cache user starting balance
        uint256 startingBalance = mockUSDC.balanceOf(users.user_0);

        // emits correct event
        vm.expectEmit({ emitter: address(edition) });
        emit TransferSingle({ operator: users.user_0, from: address(0), to: users.user_0, id: 1, amount: 1 });

        // mint token
        vm.prank(users.user_0);
        edition.mint({ to: users.user_0, id: 1, quantity: 1, extension: address(0), referrer: users.user_0, data: "" });

        assertEq(edition.balanceOf(users.user_0, 1), 1);
        assertEq(edition.totalSupply(1), 2);

        // balance should reflect mint
        assertEq(mockUSDC.balanceOf(users.user_0), startingBalance - addParams.defaultPrice);
    }

    /// @dev mint with extension
    function test__Mint_WithExtension_BalancesUnchanged() external {
        // cache user starting balance
        uint256 startingBalance = mockUSDC.balanceOf(users.user_0);

        // set extension without mint params
        vm.prank(users.creator_0);
        edition.setExtension(1, address(mockExtension), true, "");

        // emits correct event
        vm.expectEmit({ emitter: address(edition) });
        emit TransferSingle({ operator: users.user_0, from: address(0), to: users.user_0, id: 1, amount: 1 });

        // mint token
        vm.prank(users.user_0);
        edition.mint({
            to: users.user_0,
            id: 1,
            quantity: 1,
            extension: address(mockExtension),
            referrer: users.user_0,
            data: ""
        });

        assertEq(edition.balanceOf(users.user_0, 1), 1);
        assertEq(edition.totalSupply(1), 2);

        // free mint via extension - balance should be unchanged
        assertEq(mockUSDC.balanceOf(users.user_0), startingBalance);
    }

    /// @dev mint with extension - custom mint params with different price
    function test__Mint_WithExtension_CustomMintParams() external {
        uint128 customPrice = 5 * 10 ** 5; // $0.50 USDC

        // cache user starting balance
        uint256 startingBalance = mockUSDC.balanceOf(users.user_0);

        // set extension with custom mint params
        vm.prank(users.creator_0);
        edition.setExtension(1, address(mockExtension), true, abi.encode(customPrice));

        // mint token
        vm.prank(users.user_0);
        edition.mint({
            to: users.user_0,
            id: 1,
            quantity: 1,
            extension: address(mockExtension),
            referrer: users.user_0,
            data: ""
        });

        assertEq(edition.balanceOf(users.user_0, 1), 1);
        assertEq(edition.totalSupply(1), 2);

        // balance should reflect mint
        assertEq(mockUSDC.balanceOf(users.user_0), startingBalance - customPrice);
    }

    /// @dev mint gated mint with extension
    function test__Mint_WithExtension_GatedMint() external {
        uint128 customPrice = 5 * 10 ** 5; // $0.50 USDC

        // cache user starting balance
        uint256 startingBalance = mockUSDC.balanceOf(users.user_0);

        // set extension with custom mint params
        vm.prank(users.creator_0);
        edition.setExtension(1, address(mockExtension), true, abi.encode(customPrice));

        // set gated mint
        vm.prank(users.creator_0);
        edition.gateMint(1, true);

        // mint token
        vm.prank(users.user_0);
        edition.mint({
            to: users.user_0,
            id: 1,
            quantity: 1,
            extension: address(mockExtension),
            referrer: users.user_0,
            data: ""
        });

        assertEq(edition.balanceOf(users.user_0, 1), 1);
        assertEq(edition.totalSupply(1), 2);

        // balance should reflect mint
        assertEq(mockUSDC.balanceOf(users.user_0), startingBalance - customPrice);
    }
}
