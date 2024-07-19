// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

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
    function test__UpdateContractUri() external {
        string memory currentUri = edition.contractURI();
        string memory newUri = "https://new.com";

        // expect event to be emitted
        vm.expectEmit({ emitter: address(edition) });
        emit ContractURIUpdated(newUri);

        vm.prank(users.creator_0);
        edition.updateContractUri(newUri);

        assertEq(edition.contractURI(), newUri);
        assertNotEq(edition.contractURI(), currentUri);
    }
}
