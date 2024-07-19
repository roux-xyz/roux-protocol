// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { RouxEdition } from "src/RouxEdition.sol";

contract Initialize_RouxEdition_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when already initialized
    function test__RevertWhen_AlreadyInitialized() external {
        // encode params
        bytes memory initData = abi.encodeWithSelector(edition.initialize.selector, "https://new-contract-uri.com");

        // assert current implementation
        vm.prank(users.user_0);
        vm.expectRevert("Already initialized");
        edition.initialize(initData);
    }
}
