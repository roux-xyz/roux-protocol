// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { MintPortalBase } from "test/shared/MintPortalBase.t.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { IRouxMintPortal } from "src/periphery/interfaces/IRouxMintPortal.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { REFERRAL_FEE } from "src/libraries/FeesLib.sol";
import { stdError } from "forge-std/Test.sol";
import { MockExtension } from "test/mocks/MockExtension.sol";

contract MintCollection_RouxMintPortal_Integration_Test is MintPortalBase {
    function setUp() public override {
        MintPortalBase.setUp();

        usdcDepositor = users.usdcDepositor;
    }

    /// @dev mint collection with default price
    function test__MintCollection() external {
        uint256 mintCost = singleEditionCollection.price();

        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));
        uint256 initialCreatorBalance = controller.balance(creator);

        // deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // check rUSDC balance after deposit
        assertEq(mintPortal.balanceOf(user, 1), mintCost);
        assertEq(mintPortal.totalSupply(), mintCost);

        // mint collection
        vm.prank(user);
        mintPortal.mintCollection(user, singleEditionCollection, address(0), address(0), "");

        // check balances after minting
        assertEq(mintPortal.balanceOf(user, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);
        assertEq(singleEditionCollection.balanceOf(user), 1);
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);
        assertEq(controller.balance(creator), initialCreatorBalance + mintCost);

        // check if the underlying editions were minted to the token bound account
        address erc6551account = _getERC6551AccountSingleEdition(address(singleEditionCollection), 1);
        for (uint256 i = 0; i < singleEditionCollectionIds.length; i++) {
            assertEq(
                edition.balanceOf(erc6551account, singleEditionCollectionIds[i]), singleEditionCollectionQuantities[i]
            );
        }
    }

    /// @dev mint collection with referral
    function test__MintCollection_WithReferral() external {
        uint256 mintCost = singleEditionCollection.price();
        address referrer = address(users.user_1);
        uint256 referralFee = (mintCost * REFERRAL_FEE) / 10_000;

        // Initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));
        uint256 initialCreatorBalance = controller.balance(creator);
        uint256 initialReferrerBalance = controller.balance(referrer);

        // Deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // Mint collection with referral
        vm.prank(user);
        mintPortal.mintCollection(user, singleEditionCollection, address(0), referrer, "");

        // Check balances after minting
        assertEq(mintPortal.balanceOf(user, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);
        assertEq(singleEditionCollection.balanceOf(user), 1);
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);
        assertEq(controller.balance(creator), initialCreatorBalance + mintCost - referralFee);
        assertEq(controller.balance(referrer), initialReferrerBalance + referralFee);
    }

    /// @dev mint collection to another address
    function test__MintCollection_ToAddress() external {
        uint256 mintCost = singleEditionCollection.price();
        address to = address(users.user_1);

        // Initial balances
        uint256 initialUsdDepositorUSDCBalance = mockUSDC.balanceOf(usdcDepositor);
        uint256 initialPortalUSDCBalance = mockUSDC.balanceOf(address(mintPortal));

        // deposit USDC and mint rUSDC
        _depositUsdc(user, mintCost);

        // mint collection
        vm.prank(user);
        mintPortal.mintCollection(to, singleEditionCollection, address(0), address(0), "");

        // check balances after minting
        assertEq(mintPortal.balanceOf(to, 1), 0);
        assertEq(mintPortal.totalSupply(), 0);
        assertEq(singleEditionCollection.balanceOf(to), 1);
        assertEq(mockUSDC.balanceOf(usdcDepositor), initialUsdDepositorUSDCBalance - mintCost);
        assertEq(mockUSDC.balanceOf(address(mintPortal)), initialPortalUSDCBalance);
    }
}
