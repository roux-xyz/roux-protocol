// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract UpdateUri_RouxEdition_Unit_Concrete_Test is BaseTest {
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
    function test__RevertWhen_UpdateUri_NotOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.updateUri(1, "https://new.com");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates uri
    function test__UpdateUri() external {
        string memory originalUri = edition.uri(1);
        string memory newUri = "https://new.com";

        vm.expectEmit({ emitter: address(edition) });
        emit URI(newUri, 1);

        vm.prank(creator);
        edition.updateUri(1, newUri);

        assertEq(edition.uri(1), newUri);
        assertNotEq(edition.uri(1), originalUri);
    }
}
