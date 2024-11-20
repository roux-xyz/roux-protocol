// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { RouxEditionCoCreate } from "src/core/RouxEditionCoCreate.sol";
import { EditionData } from "src/types/DataTypes.sol";

contract View_RouxEditionCoCreate_Unit_Concrete_Test is BaseTest {
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
        EditionData.EditionType editionType = coCreateEdition.editionType();
        assertEq(uint256(editionType), uint256(EditionData.EditionType.CoCreate));
    }

    /// @dev contract uri is correctly set on initialize
    function test__ContractURI() external {
        bytes memory initData = abi.encode(CONTRACT_URI);

        vm.prank(users.creator_1);
        RouxEditionCoCreate newEdition = RouxEditionCoCreate(factory.createCoCreate(initData));

        assertEq(newEdition.contractURI(), CONTRACT_URI);
    }

    /// @dev owner is correctly set on initialize
    function test__Owner() external {
        bytes memory initData = abi.encode(CONTRACT_URI);

        vm.prank(users.creator_1);
        RouxEditionCoCreate newEdition = RouxEditionCoCreate(factory.createCoCreate(initData));

        assertEq(newEdition.owner(), users.creator_1);
    }

    /// @dev returns correct add window
    function test__AddWindow() external view {
        // check defaults
        (uint40 addWindowStart, uint40 addWindowEnd) = RouxEditionCoCreate(address(coCreateEdition)).addWindow();
        assertEq(addWindowStart, block.timestamp);
        assertEq(addWindowEnd, block.timestamp + 14 days);
    }

    /// @dev returns correct max adds per address
    function test__MaxAddsPerAddress() external view {
        assertEq(RouxEditionCoCreate(address(coCreateEdition)).maxAddsPerAddress(), 1);
    }

    /// @dev returns correct adds per address
    function test__AddsPerAddress() external view {
        assertEq(RouxEditionCoCreate(address(coCreateEdition)).getAddsPerAddress(address(0)), 0);
    }
}
