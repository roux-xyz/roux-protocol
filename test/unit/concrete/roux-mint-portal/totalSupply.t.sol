// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";

import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { IRouxMintPortal } from "src/periphery/interfaces/IRouxMintPortal.sol";
import { Restricted1155 } from "src/abstracts/Restricted1155.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

import "forge-std/console.sol";

contract Transfer_RouxMintPortal_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    /// @dev total supply - zero
    function test__TotalSupply_Zero() external view {
        assertEq(mintPortal.totalSupply(), 0);
    }

    /// @dev total supply - deposit
    function test__TotalSupply() external {
        // deposit underlying and mint rUSDC
        vm.prank(user);
        mintPortal.deposit(user, TOKEN_PRICE * 5);

        assertEq(mintPortal.totalSupply(), TOKEN_PRICE * 5);
    }
}
