// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

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
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ICollection } from "src/interfaces/ICollection.sol";

contract RedeemCollectionMint_RouxMintPortal_Integration_Test is MintPortalBase {
    uint256 tokenId = 1;
    uint256 quantity = 1;

    uint256 constant FREE_EDITION_MINT_ID = 2;
    uint256 constant FREE_COLLECTION_MINT_ID = 3;
    uint256 constant INVALID_TOKEN_ID = 4;
    uint256 constant PROMOTIONAL_MINTER_ROLE = 1;

    uint256 constant DEPOSIT_AMOUNT = 100 * 10 ** 6;

    EditionData.AddParams addParams;

    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        MintPortalBase.setUp();
        addParams = defaultAddParams;

        // approve mint portal as extension
        vm.prank(creator);
        singleEditionCollection.setExtension(address(mintPortal), true, "");
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev test minting with insufficient free collection balance
    function test__RevertWhen_RedeemCollectionMint_InsufficientBalance() external {
        // attempt to mint with insufficient balance of free collection mint tokens
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ERC1155.InsufficientBalance.selector));
        mintPortal.redeemCollectionMint(address(singleEditionCollection), address(0), "");
    }

    /// @dev test minting with invalid collection
    function test__RevertWhen_MintCollection_InvalidCollection() external {
        // mint promotional tokens
        _mintPromotionalTokens(user, FREE_COLLECTION_MINT_ID, quantity);

        // attempt to mint with an invalid collection address
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IRouxMintPortal.RouxMintPortal_InvalidCollection.selector));
        mintPortal.redeemCollectionMint(address(0x123), address(0), "");
    }

    /// @dev test approve mint with invalid caller
    function test__RevertWhen_ApproveMint_InvalidCaller() external {
        // attempt to mint with extension that will revert
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxMintPortal_InvalidCaller.selector);
        mintPortal.approveMint(tokenId, quantity, address(0), user, "");

        // verify that no minting occurred
        assertEq(singleEditionCollection.balanceOf(user), 0);
    }

    /// @dev reverts when minting gated collection
    function test__RevertWhen_Mint_GatedCollection() external {
        // gate the collection
        vm.prank(collectionAdmin);
        singleEditionCollection.gateMint(true);

        // mint promotional tokens
        _mintPromotionalTokens(user, FREE_COLLECTION_MINT_ID, quantity);

        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxMintPortal_GatedMint.selector);
        mintPortal.redeemCollectionMint(address(singleEditionCollection), address(0), "");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev test redeem collection mint
    function test__RedeemCollectionMint() external {
        // mint promotional tokens
        _mintPromotionalTokens(user, FREE_COLLECTION_MINT_ID, quantity);

        // check free collection mint balance
        assertEq(mintPortal.balanceOf(user, FREE_COLLECTION_MINT_ID), 1);
        assertEq(mintPortal.totalSupply(FREE_COLLECTION_MINT_ID), 1);

        // mint collection
        vm.prank(user);
        mintPortal.redeemCollectionMint(address(singleEditionCollection), address(0), "");

        // check free collection token balances after minting
        assertEq(mintPortal.balanceOf(user, FREE_COLLECTION_MINT_ID), 0);
        assertEq(mintPortal.totalSupply(FREE_COLLECTION_MINT_ID), 0);

        // check collection balances after minting
        assertEq(singleEditionCollection.balanceOf(user), 1);

        // check controller balances
        assertEq(controller.balance(collectionAdmin), 0);
    }

    function test__MintFreeCollectionMintTokens_WithPromotionalMinterRole() external {
        address promotionalMinter = address(users.user_1);

        // grant PROMOTIONAL_MINTER_ROLE to promotionalMinter
        vm.prank(users.deployer);
        OwnableRoles(address(mintPortal)).grantRoles(promotionalMinter, PROMOTIONAL_MINTER_ROLE);

        // mint free tokens using the promotional minter
        vm.prank(promotionalMinter);
        mintPortal.mintPromotionalTokens(user, FREE_COLLECTION_MINT_ID, 1);

        // check if the free token was minted
        assertEq(mintPortal.balanceOf(user, FREE_COLLECTION_MINT_ID), 1);

        // redeem the free token
        vm.prank(user);
        mintPortal.redeemCollectionMint(address(singleEditionCollection), address(0), "");

        // check if the collection token was minted
        assertEq(singleEditionCollection.balanceOf(user), 1);
    }
}
