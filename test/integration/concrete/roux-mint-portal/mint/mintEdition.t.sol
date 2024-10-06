// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { MintPortalBase } from "test/shared/MintPortalBase.t.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { IRouxMintPortal } from "src/interfaces/IRouxMintPortal.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { REFERRAL_FEE } from "src/libraries/FeesLib.sol";
import { stdError } from "forge-std/Test.sol";
import { MockExtension } from "test/mocks/MockExtension.sol";

contract MintEdition_RouxMintPortal_Integration_Test is MintPortalBase {
    uint256 tokenId = 1;
    uint256 quantity = 1;

    EditionData.AddParams addParams;

    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        MintPortalBase.setUp();
        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev test minting with insufficient rUSDC balance
    function test__RevertWhen_MintEdition_InsufficientBalance() external {
        uint256 mintCost = edition.defaultPrice(tokenId) * quantity;
        uint256 depositAmount = mintCost - 1;

        _depositUsdc(user, depositAmount);

        // attempt to mint with insufficient balance
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ERC1155.InsufficientBalance.selector));
        mintPortal.mintEdition(user, IRouxEdition(address(edition)), tokenId, quantity, address(0), address(0), "");
    }

    /// @dev test minting with invalid edition
    function test__RevertWhen_MintEdition_InvalidEdition() external {
        uint256 depositAmount = edition.defaultPrice(tokenId) * quantity;

        _depositUsdc(user, depositAmount);

        // attempt to mint with an invalid edition address
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IRouxMintPortal.RouxMintPortal_InvalidEdition.selector));
        mintPortal.mintEdition(user, IRouxEdition(address(0x123)), tokenId, quantity, address(0), address(0), "");
    }

    /// @dev extension reverts call to approve mint
    function test__RevertWhen_ApproveMint_InvalidExtension() external {
        address to = address(0x12345678);
        uint256 mintCost = edition.defaultPrice(tokenId);

        // Set up extension
        vm.prank(creator);
        edition.setExtension(tokenId, address(mockExtension), true, "");

        // deposit USDC and mint rUSDC
        _depositUsdc(to, mintCost);

        // attempt to mint with extension that will revert
        vm.prank(to);
        vm.expectRevert(MockExtension.InvalidAccount.selector);
        mintPortal.mintEdition(to, IRouxEdition(address(edition)), tokenId, 1, address(mockExtension), address(0), "");

        // verify that no minting occurred
        assertEq(edition.balanceOf(to, tokenId), 0);
        assertEq(mintPortal.balanceOf(to, 1), mintCost);
    }

    /// @dev reverts when included extension is not registered
    function test__RevertWhen_Mint_InvalidExtension() external {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidExtension.selector);
        mintPortal.mintEdition(user, IRouxEdition(address(edition)), 1, 1, address(mockExtension), address(0), "");
    }

    /// @dev reverts when minting gated edition
    function test__RevertWhen_Mint_GatedEdition() external {
        addParams.gate = true;

        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        uint256 mintCost = edition.defaultPrice(tokenId_);
        _depositUsdc(user, mintCost);

        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_GatedMint.selector);
        mintPortal.mintEdition(user, IRouxEdition(address(edition)), tokenId_, 1, address(0), address(0), "");
    }

    /* -------------------------------------------- */
    /* write                            */
    /* -------------------------------------------- */

    /// @dev test full flow of depositing USDC, minting rUSDC, and minting an edition
    function test__MintEdition() external {
        uint256 mintCost = edition.defaultPrice(tokenId) * quantity;

        // initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));

        // deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // check rUSDC balance after deposit
        assertEq(mintPortal.balanceOf(user, 1), mintCost);
        assertEq(mintPortal.totalSupply(), mintCost);

        // mint edition
        vm.prank(user);
        mintPortal.mintEdition(user, IRouxEdition(address(edition)), tokenId, quantity, address(0), address(0), "");

        // check rUSDC balances after minting
        assertEq(mintPortal.balanceOf(user, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);

        // check edition balances after minting
        assertEq(edition.balanceOf(user, tokenId), quantity);

        // Check USDC balances
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);

        // check controller balances
        assertEq(controller.balance(creator), mintCost);
    }

    /// @dev mint two different editions from single deposit
    function test__MintEdition_MultipleEditions() external {
        // deploy edition
        RouxEdition edition_ = _createEdition(creator);

        // add token
        _addToken(edition_);

        uint256 totalMintCost = edition_.defaultPrice(tokenId) * 2;

        // initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));

        // deposit USDC and mint rUSDC
        _depositUsdc(user, totalMintCost);

        // check rUSDC balance after deposit
        assertEq(mintPortal.balanceOf(user, 1), totalMintCost);
        assertEq(mintPortal.totalSupply(), totalMintCost);

        // mint edition
        vm.prank(user);
        mintPortal.mintEdition(user, IRouxEdition(address(edition)), tokenId, 1, address(0), address(0), "");

        // mint another edition
        vm.prank(user);
        mintPortal.mintEdition(user, IRouxEdition(address(edition_)), tokenId, 1, address(0), address(0), "");

        assertEq(mintPortal.balanceOf(user, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);

        // check edition balances after minting
        assertEq(edition.balanceOf(user, tokenId), 1);
        assertEq(edition_.balanceOf(user, tokenId), 1);

        // Check USDC balances
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - totalMintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);

        // check controller balances
        assertEq(controller.balance(creator), totalMintCost);
    }

    /// @dev mint with referral
    function test__MintEdition_WithReferral() external {
        uint256 mintCost = edition.defaultPrice(tokenId);
        uint256 referralFee = (mintCost * REFERRAL_FEE) / 10_000;

        // initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));
        uint256 initialCreatorBalance = controller.balance(creator);
        uint256 initialReferrerBalance = controller.balance(users.user_1);

        // deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // mint edition with referral
        vm.prank(user);
        mintPortal.mintEdition(user, IRouxEdition(address(edition)), tokenId, 1, address(0), users.user_1, "");

        // check balances after minting
        assertEq(mintPortal.balanceOf(user, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);
        assertEq(edition.balanceOf(user, tokenId), 1);
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);
        assertEq(controller.balance(creator), initialCreatorBalance + mintCost - referralFee);
        assertEq(controller.balance(users.user_1), initialReferrerBalance + referralFee);
    }

    /// @dev mint with extension
    function test__MintEdition_WithExtension() external {
        uint128 mintCost = 5 * 10 ** 5;

        // Set up extension
        vm.prank(creator);
        edition.setExtension(tokenId, address(mockExtension), true, abi.encode(mintCost));

        // initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));
        uint256 initialCreatorBalance = controller.balance(creator);

        // deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // mint edition with extension
        vm.prank(user);
        mintPortal.mintEdition(user, IRouxEdition(address(edition)), tokenId, 1, address(mockExtension), address(0), "");

        // check balances after minting
        assertEq(mintPortal.balanceOf(user, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);
        assertEq(edition.balanceOf(user, tokenId), 1);
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);
        assertEq(controller.balance(creator), initialCreatorBalance + mintCost);
    }

    /// @dev mint with extension and referral
    function test__MintEdition_WithExtensionAndReferral() external {
        uint128 customPrice = 5 * 10 ** 5;
        uint256 mintCost = customPrice;
        uint256 referralFee = (mintCost * REFERRAL_FEE) / 10_000;

        // Set up extension
        vm.prank(creator);
        edition.setExtension(tokenId, address(mockExtension), true, abi.encode(customPrice));

        // initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));
        uint256 initialCreatorBalance = controller.balance(creator);
        uint256 initialReferrerBalance = controller.balance(users.user_1);

        // deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // mint edition with extension and referral
        vm.prank(user);
        mintPortal.mintEdition(
            user, IRouxEdition(address(edition)), tokenId, 1, address(mockExtension), users.user_1, ""
        );

        // check balances after minting
        assertEq(mintPortal.balanceOf(user, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);
        assertEq(edition.balanceOf(user, tokenId), 1);
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);
        assertEq(controller.balance(creator), initialCreatorBalance + mintCost - referralFee);
        assertEq(controller.balance(users.user_1), initialReferrerBalance + referralFee);
    }

    /// @dev mint with gated extension
    function test__MintEdition_WithGatedExtension() external {
        uint128 customPrice = 5 * 10 ** 5;
        uint256 mintCost = customPrice;

        // Create a new gated edition
        RouxEdition gatedEdition = _createEdition(users.creator_1);
        EditionData.AddParams memory gatedParams = defaultAddParams;
        gatedParams.fundsRecipient = users.creator_1;
        gatedParams.gate = true;

        vm.startPrank(users.creator_1);
        uint256 gatedTokenId = gatedEdition.add(gatedParams);
        gatedEdition.setExtension(gatedTokenId, address(mockExtension), true, abi.encode(customPrice));
        vm.stopPrank();

        // initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));
        uint256 initialCreatorBalance = controller.balance(users.creator_1);

        // deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // mint gated edition with extension
        vm.prank(user);
        mintPortal.mintEdition(
            user, IRouxEdition(address(gatedEdition)), gatedTokenId, 1, address(mockExtension), address(0), ""
        );

        // check balances after minting
        assertEq(mintPortal.balanceOf(user, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);
        assertEq(gatedEdition.balanceOf(user, gatedTokenId), 1);
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);
        assertEq(controller.balance(users.creator_1), initialCreatorBalance + mintCost);
    }

    /// @dev mint token to another address
    function test__MintEdition_ToAddress() external {
        uint256 mintCost = edition.defaultPrice(tokenId) * quantity;

        // initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));

        // deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // mint edition
        vm.prank(user);
        mintPortal.mintEdition(
            users.user_2, IRouxEdition(address(edition)), tokenId, quantity, address(0), address(0), ""
        );

        // check balances after minting
        assertEq(mintPortal.balanceOf(users.user_2, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);
        assertEq(edition.balanceOf(users.user_2, tokenId), 1);
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);
    }
}
