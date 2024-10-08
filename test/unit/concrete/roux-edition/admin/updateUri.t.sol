// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

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
        edition.updateUri(1, IPFS_HASH_DIGEST);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates uri
    function test__UpdateUri() external {
        bytes32 newHashDigest = 0xD12E8769BD2A43AAD41B12C4DDB1F7AE797D050D0ABF87EEB9B1834B9B186A28;

        string memory originalUri = edition.uri(1);
        string memory newUri = "ipfs://bafybeigrf2dwtpjkiovnigysyto3d55opf6qkdikx6d65onrqnfzwgdkfa";

        vm.expectEmit({ emitter: address(edition) });
        emit URI(newUri, 1);

        vm.prank(creator);
        edition.updateUri(1, newHashDigest);

        assertEq(edition.uri(1), newUri);
        assertNotEq(edition.uri(1), originalUri);
    }
}
