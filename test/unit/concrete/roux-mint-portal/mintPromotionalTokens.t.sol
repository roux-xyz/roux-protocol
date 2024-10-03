// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

contract MintPromotionalTokens_RouxMintPortal_Unit_Concrete_Test is BaseTest {
    uint256 constant FREE_EDITION_MINT_ID = 2;
    uint256 constant FREE_COLLECTION_MINT_ID = 3;
    uint256 constant INVALID_TOKEN_ID = 4;
    uint256 constant PROMOTIONAL_MINTER_ROLE = 1;

    uint256 constant MINT_AMOUNT = 100;

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when caller is not owner
    function test__RevertWhen_CallerIsNotOwner() external {
        vm.prank(users.user_1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        mintPortal.mintPromotionalTokens(users.user_1, FREE_EDITION_MINT_ID, MINT_AMOUNT);
    }

    /// @dev reverts when token id is invalid
    function test__RevertWhen_InvalidTokenId() external {
        vm.prank(users.deployer);
        vm.expectRevert(ErrorsLib.RouxMintPortal_InvalidToken.selector);
        mintPortal.mintPromotionalTokens(users.user_1, INVALID_TOKEN_ID, MINT_AMOUNT);
    }

    /// @dev test that only accounts with PROMOTIONAL_MINTER_ROLE can mint free tokens
    function test__RevertWhen_MintFreeTokens_WithoutPromotionalMinterRole() external {
        address nonPromotionalMinter = address(users.user_1);

        // attempt to mint free tokens without the role
        vm.prank(nonPromotionalMinter);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        mintPortal.mintPromotionalTokens(user, FREE_EDITION_MINT_ID, 1);

        // check that no tokens were minted
        assertEq(mintPortal.balanceOf(user, FREE_EDITION_MINT_ID), 0);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function test__MintFreeEditionMintTokens() external {
        vm.prank(users.deployer);
        mintPortal.mintPromotionalTokens(users.user_1, FREE_EDITION_MINT_ID, MINT_AMOUNT);

        assertEq(mintPortal.balanceOf(users.user_1, FREE_EDITION_MINT_ID), MINT_AMOUNT);
        assertEq(mintPortal.totalSupply(FREE_EDITION_MINT_ID), MINT_AMOUNT);
    }

    function test__MintFreeCollectionMintTokens() external {
        vm.prank(users.deployer);
        mintPortal.mintPromotionalTokens(users.user_1, FREE_COLLECTION_MINT_ID, MINT_AMOUNT);

        assertEq(mintPortal.balanceOf(users.user_1, FREE_COLLECTION_MINT_ID), MINT_AMOUNT);
        assertEq(mintPortal.totalSupply(FREE_COLLECTION_MINT_ID), MINT_AMOUNT);
    }

    function test__MintFreeEditionMintTokens_EmitsEvent() external {
        vm.prank(users.deployer);
        vm.expectEmit({ emitter: address(mintPortal) });
        emit ERC1155.TransferSingle(
            address(users.deployer), address(0), users.user_1, FREE_EDITION_MINT_ID, MINT_AMOUNT
        );
        mintPortal.mintPromotionalTokens(users.user_1, FREE_EDITION_MINT_ID, MINT_AMOUNT);
    }

    function test__MultipleMints() external {
        vm.startPrank(users.deployer);

        mintPortal.mintPromotionalTokens(users.user_1, FREE_EDITION_MINT_ID, MINT_AMOUNT);
        mintPortal.mintPromotionalTokens(users.user_2, FREE_EDITION_MINT_ID, MINT_AMOUNT * 2);

        vm.stopPrank();

        assertEq(mintPortal.balanceOf(users.user_1, FREE_EDITION_MINT_ID), MINT_AMOUNT);
        assertEq(mintPortal.balanceOf(users.user_2, FREE_EDITION_MINT_ID), MINT_AMOUNT * 2);
        assertEq(mintPortal.totalSupply(FREE_EDITION_MINT_ID), MINT_AMOUNT * 3);
    }

    function test__MintFreeEditionMintTokens_WithPromotionalMinterRole() external {
        address promotionalMinter = address(users.user_1);

        // grant PROMOTIONAL_MINTER_ROLE to promotionalMinter
        vm.prank(users.deployer);
        OwnableRoles(address(mintPortal)).grantRoles(promotionalMinter, PROMOTIONAL_MINTER_ROLE);

        // mint free tokens using the promotional minter
        vm.prank(promotionalMinter);
        mintPortal.mintPromotionalTokens(user, FREE_EDITION_MINT_ID, 1);

        // check if the free token was minted
        assertEq(mintPortal.balanceOf(user, FREE_EDITION_MINT_ID), 1);
    }
}
