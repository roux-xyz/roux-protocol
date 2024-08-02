// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { RouxEdition } from "src/RouxEdition.sol";

contract Initialize_RouxEdition_Integration_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev owner is correctly set on initialize
    function test__Initialize_Owner() external {
        // encode params
        bytes memory initData = abi.encode(CONTRACT_URI);

        // new edition instance
        vm.prank(users.creator_1);
        RouxEdition newEdition = RouxEdition(factory.create(initData));

        assertEq(newEdition.owner(), users.creator_1);
    }

    /// @dev controller approved for currency
    function test__Initialize_ControllerApprovedForCurrency() external {
        // encode params
        bytes memory initData = abi.encode(CONTRACT_URI);

        // new edition instance
        vm.prank(users.creator_1);
        RouxEdition newEdition = RouxEdition(factory.create(initData));

        uint256 allowance = mockUSDC.allowance(address(newEdition), address(controller));
        assertEq(allowance, type(uint256).max);
    }

    /// @dev contract uri is correctly set on initialize
    function test__Initialize_ContractURI() external {
        // encode params
        bytes memory initData = abi.encode(CONTRACT_URI);

        // new edition instance
        vm.prank(users.creator_1);
        RouxEdition newEdition = RouxEdition(factory.create(initData));

        assertEq(newEdition.contractURI(), CONTRACT_URI);
    }
}
