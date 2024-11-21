// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { RouxCommunityEdition } from "src/core/RouxCommunityEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";

contract View_RouxCommunityEdition_Unit_Concrete_Test is BaseTest {
    EditionData.AddParams addParams;

    function setUp() public override {
        BaseTest.setUp();

        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /// @dev edition type
    function test__EditionType() external view {
        EditionData.EditionType editionType = communityEdition.editionType();
        assertEq(uint256(editionType), uint256(EditionData.EditionType.Community));
    }

    /// @dev contract uri is correctly set on initialize
    function test__ContractURI() external {
        bytes memory initData = abi.encode(CONTRACT_URI);

        vm.prank(users.creator_1);
        RouxCommunityEdition newEdition = RouxCommunityEdition(factory.createCommunity(initData));

        assertEq(newEdition.contractURI(), CONTRACT_URI);
    }

    /// @dev owner is correctly set on initialize
    function test__Owner() external {
        bytes memory initData = abi.encode(CONTRACT_URI);

        vm.prank(users.creator_1);
        RouxCommunityEdition newEdition = RouxCommunityEdition(factory.createCommunity(initData));

        assertEq(newEdition.owner(), users.creator_1);
    }

    /// @dev returns correct add window
    function test__AddWindow() external view {
        // check defaults
        (uint40 addWindowStart, uint40 addWindowEnd) = RouxCommunityEdition(address(communityEdition)).addWindow();
        assertEq(addWindowStart, block.timestamp);
        assertEq(addWindowEnd, block.timestamp + 14 days);
    }

    /// @dev returns correct max adds per address
    function test__MaxAddsPerAddress() external view {
        assertEq(RouxCommunityEdition(address(communityEdition)).maxAddsPerAddress(), 1);
    }

    /// @dev returns correct adds per address
    function test__AddsPerAddress() external view {
        assertEq(RouxCommunityEdition(address(communityEdition)).getAddsPerAddress(address(0)), 0);
    }

    /// @dev returns correct max tokens
    function test__MaxTokens() external view {
        assertEq(RouxCommunityEdition(address(communityEdition)).maxTokens(), type(uint256).max);
    }
}
