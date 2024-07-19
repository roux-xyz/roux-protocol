// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";

contract View_RouxEdition_Unit_Concrete_Test is BaseTest {
    function setUp() public override {
        BaseTest.setUp();
    }

    /// @dev returns correct implementation version
    function test__Implementation() external view {
        assertEq(edition.IMPLEMENTATION_VERSION(), "0.1");
    }

    /// @dev returns correct owner
    function test__Owner() external view {
        assertEq(edition.owner(), users.creator_0);
    }

    /// @dev returns correct creator
    function test__Creator() external view {
        assertEq(edition.creator(1), users.creator_0);
    }

    /// @dev returns correct current token id
    function test__CurrentToken() external view {
        assertEq(edition.currentToken(), 1);
    }

    /// @dev returns correct currency address
    function test__Currency() external view {
        assertEq(edition.currency(), address(mockUSDC));
    }

    /// @dev returns correct total supply
    function test__TotalSupply() external view {
        // token minted to creator on add in setup
        assertEq(edition.totalSupply(1), 1);
    }

    /// @dev returns correct uri
    function test__Uri() external view {
        assertEq(edition.uri(1), TOKEN_URI);
    }

    /// @dev returns correct contract uri
    function test__ContractUri() external view {
        assertEq(edition.contractURI(), CONTRACT_URI);
    }

    /// @dev returns whether token exists - when true
    function test__Exists_True() external view {
        assertEq(edition.exists(1), true);
    }

    /// @dev returns whether token exists - when false
    function test__Exists_False() external view {
        assertEq(edition.exists(2), false);
    }

    /// @dev returns whether extension exists - when zero
    function test__Exists_Zero() external view {
        assertEq(edition.exists(0), false);
    }

    /// @dev returns whether token is gated - when true
    function test__IsGated_True() external {
        vm.prank(users.creator_0);
        edition.gateMint(1, true);

        assertTrue(edition.isGated(1));
    }

    /// @dev returns whether token is gated - when false
    function test__IsGated_False() external view {
        assertFalse(edition.isGated(1));
    }

    /// @dev returns whether extension is set - when true
    function test__IsExtension() external {
        // add extension to token
        vm.prank(users.creator_0);
        edition.setExtension(1, address(mockExtension), true, "");

        assertTrue(edition.isExtension(1, address(mockExtension)));
    }

    /// @dev returns whether extension is set - when false
    function test__IsExtension_False() external view {
        assertFalse(edition.isExtension(1, address(mockExtension)));
    }
}
