// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { RouxEditionCoCreate } from "src/core/RouxEditionCoCreate.sol";
import { Initializable } from "solady/utils/Initializable.sol";

contract Initialize_RouxEditionCoCreate_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when already initialized
    function test__RevertWhen_AlreadyInitialized() external {
        bytes memory initData = abi.encodeWithSelector(coCreateEdition.initialize.selector, CONTRACT_URI);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        coCreateEdition.initialize(initData);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev controller approved for currency
    function test__Initialize_ControllerApprovedForCurrency() external {
        bytes memory initData = abi.encode(CONTRACT_URI);

        vm.prank(users.creator_1);
        RouxEditionCoCreate newEdition = RouxEditionCoCreate(factory.createCoCreate(initData));

        uint256 allowance = mockUSDC.allowance(address(newEdition), address(controller));
        assertEq(allowance, type(uint256).max);
    }
}
