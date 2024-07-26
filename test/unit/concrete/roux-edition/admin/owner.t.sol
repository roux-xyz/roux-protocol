// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract Owner_RouxEdition_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev only owner can transfer ownership
    function test__RevertWhen_TransferOwnership_NotOwner() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(user);
        edition.transferOwnership(users.user_1);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully transfers ownership
    function test__TransferOwnership() external useEditionAdmin(edition) {
        edition.transferOwnership(users.creator_1);
        assertEq(edition.owner(), users.creator_1);
    }
}
