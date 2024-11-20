// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";

contract View_RouxEdition_Unit_Concrete_Test is BaseTest {
    EditionData.AddParams addParams;

    function setUp() public override {
        BaseTest.setUp();

        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /// @dev returns correct edition type
    function test__EditionType() external view {
        assertEq(uint256(edition.editionType()), uint256(EditionData.EditionType.Standard));
    }

    /// @dev returns correct owner
    function test__Owner() external view {
        assertEq(edition.owner(), creator);
        assertEq(coCreateEdition.owner(), creator);
    }

    /// @dev returns correct creator
    function test__Creator() external view {
        assertEq(edition.creator(1), creator);
        assertEq(coCreateEdition.creator(1), creator);
    }

    /// @dev returns correct current token id
    function test__CurrentToken() external view {
        assertEq(edition.currentToken(), 1);
        assertEq(coCreateEdition.currentToken(), 1);
    }

    /// @dev returns correct currency address
    function test__Currency() external view {
        assertEq(edition.currency(), address(mockUSDC));
        assertEq(coCreateEdition.currency(), address(mockUSDC));
    }

    /// @dev returns correct total supply
    function test__TotalSupply() external view {
        // token minted to creator on add in setup
        assertEq(edition.totalSupply(1), 1);
        assertEq(coCreateEdition.totalSupply(1), 1);
    }

    /// @dev returns correct contract uri
    function test__ContractUri() external view {
        assertEq(edition.contractURI(), CONTRACT_URI);
        assertEq(coCreateEdition.contractURI(), CONTRACT_URI);
    }

    /// @dev returns whether token exists - when true
    function test__Exists_True() external view {
        assertEq(edition.exists(1), true);
        assertEq(coCreateEdition.exists(1), true);
    }

    /// @dev returns whether token exists - when false
    function test__Exists_False() external view {
        assertEq(edition.exists(2), false);
        assertEq(coCreateEdition.exists(2), false);
    }

    /// @dev returns whether extension exists - when zero
    function test__Exists_Zero() external view {
        assertEq(edition.exists(0), false);
        assertEq(coCreateEdition.exists(0), false);
    }

    /// @dev returns whether token is gated - when false
    function test__IsGated_False() external view {
        assertFalse(edition.isGated(1));
        assertFalse(coCreateEdition.isGated(1));
    }

    /// @dev returns whether extension is set - when true
    function test__IsExtension() external {
        // add extension to token
        vm.prank(creator);
        edition.setExtension(1, address(mockExtension), true, "");

        assertTrue(edition.isRegisteredExtension(1, address(mockExtension)));
    }

    /// @dev returns whether extension is set on co-create - when true
    function test__IsExtension_CoCreate() external {
        // add extension to token
        vm.prank(creator);
        coCreateEdition.setExtension(1, address(mockExtension), true, "");

        assertTrue(coCreateEdition.isRegisteredExtension(1, address(mockExtension)));
    }

    /// @dev returns whether extension is set - when false
    function test__IsExtension_False() external view {
        assertFalse(edition.isRegisteredExtension(1, address(mockExtension)));
        assertFalse(coCreateEdition.isRegisteredExtension(1, address(mockExtension)));
    }

    /// @dev returns whether token is multi edition collection mint eligible - when true
    function test__IsMultiEditionCollectionMintEligible_True() external view {
        assertTrue(edition.multiCollectionMintEligible(1, address(mockUSDC)));
        assertTrue(coCreateEdition.multiCollectionMintEligible(1, address(mockUSDC)));
    }

    /// @dev returns whether token is multi edition collection mint eligible - when false - token does not exist
    function test__IsMultiEditionCollectionMintEligible_False_TokenDoesNotExist() external view {
        assertFalse(edition.multiCollectionMintEligible(0, address(mockUSDC)));
        assertFalse(edition.multiCollectionMintEligible(2, address(mockUSDC)));

        assertFalse(coCreateEdition.multiCollectionMintEligible(0, address(mockUSDC)));
        assertFalse(coCreateEdition.multiCollectionMintEligible(2, address(mockUSDC)));
    }

    /// @dev returns whether token is multi edition collection mint eligible - when false - token is gated
    function test__IsMultiEditionCollectionMintEligible_False_WithGate() external {
        // update default add params
        addParams.gate = true;

        // create edition instance
        RouxEdition edition_ = _createEdition(users.creator_1);
        RouxEdition coCreateEdition_ = _createCoCreateEdition(users.creator_1);

        // add token
        vm.prank(users.creator_1);
        uint256 tokenId_ = edition_.add(addParams);

        vm.prank(users.creator_1);
        uint256 tokenId_coCreate = coCreateEdition_.add(addParams);

        assertFalse(edition_.multiCollectionMintEligible(tokenId_, address(mockUSDC)));
        assertFalse(coCreateEdition_.multiCollectionMintEligible(tokenId_coCreate, address(mockUSDC)));
    }

    /// @dev returns whether token is multi edition collection mint eligible - when false - currency
    function test__IsMultiEditionCollectionMintEligible_False_WithCurrency() external view {
        assertFalse(edition.multiCollectionMintEligible(1, address(0)));
        assertFalse(coCreateEdition.multiCollectionMintEligible(1, address(0)));
    }
}
