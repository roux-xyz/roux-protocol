// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";

import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxMintPortal } from "src/interfaces/IRouxMintPortal.sol";
import { Restricted1155 } from "src/abstracts/Restricted1155.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract Transfer_RouxMintPortal_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();

        // deposit underlying and mint rUSDC
        vm.prank(user);
        mintPortal.deposit(user, TOKEN_PRICE * 5);
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev safe transer reverts
    function test__RevertWhen_SafeTransferFrom_Reverts() external {
        vm.prank(user);
        vm.expectRevert(Restricted1155.Restricted1155_TransferNotAllowed.selector);
        mintPortal.safeTransferFrom(user, users.user_1, 1, 1, "");
    }

    /// @dev safe batch transfer reverts
    function test__RevertWhen_SafeBatchTransferFrom_Reverts() external {
        vm.prank(user);
        vm.expectRevert(Restricted1155.Restricted1155_TransferNotAllowed.selector);
        mintPortal.safeBatchTransferFrom(user, users.user_1, new uint256[](1), new uint256[](1), "");
    }

    /// @dev set approval reverts
    function test__RevertWhen_SetApproval_Reverts() external {
        vm.prank(user);
        vm.expectRevert(Restricted1155.Restricted1155_TransferNotAllowed.selector);
        mintPortal.setApprovalForAll(user, true);
    }
}
