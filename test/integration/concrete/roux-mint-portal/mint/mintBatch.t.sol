// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { MintPortalBase } from "test/shared/MintPortalBase.t.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { IRouxMintPortal } from "src/interfaces/IRouxMintPortal.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { stdError } from "forge-std/Test.sol";
import { EditionData } from "src/types/DataTypes.sol";

contract MintBatch_RouxMintPortal_Integration_Test is MintPortalBase {
    uint256[] tokenIds;
    uint256[] quantities;
    address[] extensions;

    EditionData.AddParams addParams;

    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        MintPortalBase.setUp();

        usdcDepositor = users.usdcDepositor;

        tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        quantities = new uint256[](2);
        quantities[0] = 1;
        quantities[1] = 2;

        extensions = new address[](2);
        extensions[0] = address(0);
        extensions[1] = address(0);

        // Add another token to the edition
        vm.prank(creator);
        edition.add(defaultAddParams);

        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev test batch minting with insufficient rUSDC balance
    function test__RevertWhen_MintBatch_InsufficientBalance() external {
        uint256 mintCost =
            edition.defaultPrice(tokenIds[0]) * quantities[0] + edition.defaultPrice(tokenIds[1]) * quantities[1];
        uint256 depositAmount = mintCost - 1;

        _depositUsdc(user, depositAmount);

        // attempt to mint with insufficient balance
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ERC1155.InsufficientBalance.selector));
        mintPortal.batchMintEdition(
            user, IRouxEdition(address(edition)), tokenIds, quantities, extensions, address(0), ""
        );
    }

    /// @dev test batch minting with invalid edition
    function test__RevertWhen_MintBatch_InvalidEdition() external {
        uint256 mintCost =
            edition.defaultPrice(tokenIds[0]) * quantities[0] + edition.defaultPrice(tokenIds[1]) * quantities[1];

        _depositUsdc(user, mintCost);

        // attempt to mint with an invalid edition address
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IRouxMintPortal.RouxMintPortal_InvalidEdition.selector));
        mintPortal.batchMintEdition(
            user, IRouxEdition(address(0x123)), tokenIds, quantities, extensions, address(0), ""
        );
    }

    // todo: test gated edition in batch mint

    /* -------------------------------------------- */
    /* integration tests                            */
    /* -------------------------------------------- */

    /// @dev test full flow of depositing USDC, minting rUSDC, and batch minting editions
    function test__MintBatch() external {
        uint256 mintCost =
            edition.defaultPrice(tokenIds[0]) * quantities[0] + edition.defaultPrice(tokenIds[1]) * quantities[1];

        // initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));

        // deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // check rUSDC balance after deposit
        assertEq(mintPortal.balanceOf(user, 1), mintCost);
        assertEq(mintPortal.totalSupply(), mintCost);

        // batch mint editions
        vm.prank(user);
        mintPortal.batchMintEdition(
            user, IRouxEdition(address(edition)), tokenIds, quantities, extensions, address(0), ""
        );

        // check rUSDC balances after minting
        assertEq(mintPortal.balanceOf(user, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);

        // check edition balances after minting
        assertEq(edition.balanceOf(user, tokenIds[0]), quantities[0]);
        assertEq(edition.balanceOf(user, tokenIds[1]), quantities[1]);

        // Check USDC balances
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);

        // check controller balances
        assertEq(controller.balance(creator), mintCost);
    }

    function test__MintBatch_WithExtensions() external {
        uint128 customPrice1 = 3 * 10 ** 5;
        uint128 customPrice2 = 4 * 10 ** 5;

        // Set up extensions
        vm.startPrank(creator);
        edition.setExtension(tokenIds[0], address(mockExtension), true, abi.encode(customPrice1));
        edition.setExtension(tokenIds[1], address(mockExtension), true, abi.encode(customPrice2));
        vm.stopPrank();

        extensions[0] = address(mockExtension);
        extensions[1] = address(mockExtension);

        uint256 mintCost = (customPrice1 * quantities[0]) + (customPrice2 * quantities[1]);

        // initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));

        // deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // check rUSDC balance after deposit
        assertEq(mintPortal.balanceOf(user, 1), mintCost);
        assertEq(mintPortal.totalSupply(), mintCost);

        // batch mint editions with extensions
        vm.prank(user);
        mintPortal.batchMintEdition(
            user, IRouxEdition(address(edition)), tokenIds, quantities, extensions, address(0), ""
        );

        // check rUSDC balances after minting
        assertEq(mintPortal.balanceOf(user, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);

        // check edition balances after minting
        assertEq(edition.balanceOf(user, tokenIds[0]), quantities[0]);
        assertEq(edition.balanceOf(user, tokenIds[1]), quantities[1]);

        // Check USDC balances
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);

        // check controller balances
        assertEq(controller.balance(creator), mintCost);
    }

    /// @dev test batch minting with mix of extensions and default pricing
    function test__MintBatch_WithMixedExtensions() external {
        uint128 customPrice = 3 * 10 ** 5;

        // Set up extension for the first token only
        vm.prank(creator);
        edition.setExtension(tokenIds[0], address(mockExtension), true, abi.encode(customPrice));

        extensions[0] = address(mockExtension);
        extensions[1] = address(0);

        uint256 mintCost = (customPrice * quantities[0]) + (edition.defaultPrice(tokenIds[1]) * quantities[1]);

        // initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));

        // deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // check rUSDC balance after deposit
        assertEq(mintPortal.balanceOf(user, 1), mintCost);
        assertEq(mintPortal.totalSupply(), mintCost);

        // batch mint editions with mixed extensions
        vm.prank(user);
        mintPortal.batchMintEdition(
            user, IRouxEdition(address(edition)), tokenIds, quantities, extensions, address(0), ""
        );

        // check rUSDC balances after minting
        assertEq(mintPortal.balanceOf(user, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);

        // check edition balances after minting
        assertEq(edition.balanceOf(user, tokenIds[0]), quantities[0]);
        assertEq(edition.balanceOf(user, tokenIds[1]), quantities[1]);

        // Check USDC balances
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);

        // check controller balances
        assertEq(controller.balance(creator), mintCost);
    }

    /// @dev mint token to another address
    function test__MintBatch_ToAddress() external {
        uint256 mintCost =
            edition.defaultPrice(tokenIds[0]) * quantities[0] + edition.defaultPrice(tokenIds[1]) * quantities[1];

        // initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));

        // deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // batch mint editions
        vm.prank(user);
        mintPortal.batchMintEdition(
            users.user_2, IRouxEdition(address(edition)), tokenIds, quantities, extensions, address(0), ""
        );

        // check balances after minting
        assertEq(mintPortal.balanceOf(users.user_2, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);
        assertEq(edition.balanceOf(users.user_2, tokenIds[0]), 1);
        assertEq(edition.balanceOf(users.user_2, tokenIds[1]), 2);
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);
    }
}
