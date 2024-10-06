// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";

contract UpdateUri_RouxEdition_Integration_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when not owner
    function test__RevertWhen_UpdateUri_HasChild() external {
        _createFork(edition, 1, users.creator_1);

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_UriFrozen.selector);
        edition.updateUri(1, "https://new.com");
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */
}
