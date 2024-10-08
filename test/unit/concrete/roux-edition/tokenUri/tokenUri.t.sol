// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { GenerateTokenUriHarness } from "test/harness/GenerateTokenUriHarness.sol";

contract GenerateTokenUri_Unit_Concrete_Test is BaseTest {
    GenerateTokenUriHarness public harness;

    function setUp() public override {
        BaseTest.setUp();

        harness = new GenerateTokenUriHarness(address(0x1), address(0x2), address(0x3), address(0x4));
    }

    function test__GenerateTokenUri() public view {
        bytes32 hashDigest = 0x1b036544434cea9770a413fd03e0fb240e1ccbd10a452f7dba85c8eca9ca3eda;
        assertEq(
            harness.generateTokenUri(hashDigest), "ipfs://bafybeia3ansuiq2m5klxbjat7ub6b6zebyomxuikiuxx3oufzdwktsr63i"
        );

        hashDigest = 0xC3C4733EC8AFFD06CF9E9FF50FFC6BCD2EC85A6170004BB709669C31DE94391A;
        assertEq(
            harness.generateTokenUri(hashDigest), "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
        );

        hashDigest = 0xD12E8769BD2A43AAD41B12C4DDB1F7AE797D050D0ABF87EEB9B1834B9B186A28;

        assertEq(
            harness.generateTokenUri(hashDigest), "ipfs://bafybeigrf2dwtpjkiovnigysyto3d55opf6qkdikx6d65onrqnfzwgdkfa"
        );
    }
}
