// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { GenerateTokenUriHarness } from "test/harness/GenerateTokenUriHarness.sol";
import { EditionData } from "src/types/DataTypes.sol";

contract Uri_Unit_Concrete_Test is BaseTest {
    GenerateTokenUriHarness public harness;

    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */
    EditionData.AddParams addParams;

    function setUp() public override {
        BaseTest.setUp();

        addParams = defaultAddParams;

        harness = new GenerateTokenUriHarness(address(0x1), address(0x2), address(0x3), address(0x4));
    }

    function test__GenerateTokenUri() public view {
        bytes32 hashDigest = 0x1b036544434cea9770a413fd03e0fb240e1ccbd10a452f7dba85c8eca9ca3eda;
        assertEq(
            harness.generateTokenUri(hashDigest), "ipfs://bafkreia3ansuiq2m5klxbjat7ub6b6zebyomxuikiuxx3oufzdwktsr63i"
        );

        hashDigest = 0xC3C4733EC8AFFD06CF9E9FF50FFC6BCD2EC85A6170004BB709669C31DE94391A;
        assertEq(
            harness.generateTokenUri(hashDigest), "ipfs://bafkreigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
        );

        hashDigest = 0xD12E8769BD2A43AAD41B12C4DDB1F7AE797D050D0ABF87EEB9B1834B9B186A28;

        assertEq(
            harness.generateTokenUri(hashDigest), "ipfs://bafkreigrf2dwtpjkiovnigysyto3d55opf6qkdikx6d65onrqnfzwgdkfa"
        );

        hashDigest = 0xf17a42406d043e33165b7c13d4d4e616b9d09551e3e310f658b323c06a63779f;
        assertEq(
            harness.generateTokenUri(hashDigest), "ipfs://bafkreihrpjbea3iehyzrmw34cpknjzqwxhijkupd4mipmwftepaguy3xt4"
        );
    }

    function test__Uri() public view {
        assertEq(edition.uri(1), TOKEN_URI);
    }

    /// @dev test default uri with new token
    function test__DefaultUri() public {
        // modify default add params
        addParams.ipfsHash = "";

        // add token
        vm.prank(creator);
        uint256 tokenId = edition.add(addParams);

        // default uri is set after add
        assertEq(edition.uri(tokenId), "");
    }

    function test__AddUriToArray() public {
        vm.prank(creator);
        edition.updateUri(1, 0xC3C4733EC8AFFD06CF9E9FF50FFC6BCD2EC85A6170004BB709669C31DE94391A);

        // uri returns most recently added uri
        assertEq(edition.uri(1), "ipfs://bafkreigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi");

        // overloaded uri with index returns uri at index
        assertEq(edition.uri(1, 0), TOKEN_URI);
        assertEq(edition.uri(1, 1), "ipfs://bafkreigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi");
    }
}
