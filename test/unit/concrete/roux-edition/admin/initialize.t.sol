// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { Initializable } from "solady/utils/Initializable.sol";

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
    function test__RevertWhen_AlreadyInitialized() external useEditionAdmin(address(edition)) {
        bytes memory initData = abi.encodeWithSelector(edition.initialize.selector, "https://new-contract-uri.com");

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        edition.initialize(initData);
    }
}
