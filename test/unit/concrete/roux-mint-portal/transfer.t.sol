// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { MintPortalBase } from "test/shared/MintPortalBase.t.sol";

import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxMintPortal } from "src/interfaces/IRouxMintPortal.sol";
import { Restricted1155 } from "src/abstracts/Restricted1155.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract Transfer_RouxMintPortal_Unit_Concrete_Test is MintPortalBase {
    uint256 constant RESTRICTED_TOKEN_ID = 1;
    uint256 constant FREE_EDITION_MINT_ID = 2;
    uint256 constant FREE_COLLECTION_MINT_ID = 3;

    function setUp() public override {
        MintPortalBase.setUp();

        // deposit underlying and mint rUSDC
        _depositUsdc(user, TOKEN_PRICE * 5);

        // Mint a non-restricted token for testing
        vm.prank(users.deployer);
        mintPortal.mintPromotionalTokens(user, FREE_EDITION_MINT_ID, 1);
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when attempting to transfer a restricted token
    function test__RevertWhen_SafeTransferFrom_Reverts() external {
        vm.prank(user);
        vm.expectRevert(Restricted1155.Restricted1155_TransferNotAllowed.selector);
        mintPortal.safeTransferFrom(user, users.user_1, RESTRICTED_TOKEN_ID, 1, "");
    }

    /// @dev reverts when attempting to batch transfer a restricted token
    function test__RevertWhen_SafeBatchTransferFrom_Reverts() external {
        uint256[] memory ids = new uint256[](1);
        ids[0] = RESTRICTED_TOKEN_ID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.prank(user);
        vm.expectRevert(Restricted1155.Restricted1155_TransferNotAllowed.selector);
        mintPortal.safeBatchTransferFrom(user, users.user_1, ids, amounts, "");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev succeeds when transferring a non-restricted token
    function test__SafeTransferFrom_Succeeds_ForNonRestrictedToken() external {
        vm.prank(user);
        mintPortal.safeTransferFrom(user, users.user_1, FREE_EDITION_MINT_ID, 1, "");

        assertEq(mintPortal.balanceOf(users.user_1, FREE_EDITION_MINT_ID), 1);
        assertEq(mintPortal.balanceOf(user, FREE_EDITION_MINT_ID), 0);
    }

    /// @dev succeeds when batch transferring a non-restricted token
    function test__SafeBatchTransferFrom_Succeeds_ForNonRestrictedToken() external {
        uint256[] memory ids = new uint256[](1);
        ids[0] = FREE_EDITION_MINT_ID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.prank(user);
        mintPortal.safeBatchTransferFrom(user, users.user_1, ids, amounts, "");

        assertEq(mintPortal.balanceOf(users.user_1, FREE_EDITION_MINT_ID), 1);
        assertEq(mintPortal.balanceOf(user, FREE_EDITION_MINT_ID), 0);
    }

    /// @dev succeeds when setting approval for all
    function test__SetApprovalForAll_Succeeds() external {
        vm.prank(user);
        mintPortal.setApprovalForAll(users.user_1, true);

        assertTrue(mintPortal.isApprovedForAll(user, users.user_1));
    }

    /// @dev succeeds when approved operator can transfer
    function test__ApprovedOperator_CanTransferNonRestrictedToken() external {
        vm.prank(user);
        mintPortal.setApprovalForAll(users.user_1, true);

        vm.prank(users.user_1);
        mintPortal.safeTransferFrom(user, users.user_2, FREE_EDITION_MINT_ID, 1, "");

        assertEq(mintPortal.balanceOf(users.user_2, FREE_EDITION_MINT_ID), 1);
        assertEq(mintPortal.balanceOf(user, FREE_EDITION_MINT_ID), 0);
    }
}
