// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract UpdateContractUri_RouxEdition_Unit_Concrete_Test is BaseTest {
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
    function test__RevertWhen_UpdateContractUri_NotOwner() external {
        vm.prank(users.user_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.updateContractUri("https://new.com");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates uri
    function test__UpdateContractUri() external useEditionAdmin(edition) {
        string memory currentUri = edition.contractURI();
        string memory newUri = "https://new.com";

        vm.expectEmit({ emitter: address(edition) });
        emit EventsLib.ContractURIUpdated(newUri);

        edition.updateContractUri(newUri);

        assertEq(edition.contractURI(), newUri);
        assertNotEq(edition.contractURI(), currentUri);
    }
}
