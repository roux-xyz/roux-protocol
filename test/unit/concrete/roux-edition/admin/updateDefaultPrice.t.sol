// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract UpdateDefaultPrice_RouxEdition_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when not owner
    function test__RevertWhen_UpdateDefaultPrice_NotOwner() external {
        vm.prank(users.user_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.updateDefaultPrice(1, 5 * 10 ** 5);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates default price
    function test__UpdateDefaultPrice() external useEditionAdmin(edition) {
        uint128 currentPrice = edition.defaultPrice(1);
        uint128 newPrice = 5 * 10 ** 5;

        vm.expectEmit({ emitter: address(edition) });
        emit EventsLib.DefaultPriceUpdated(1, newPrice);

        edition.updateDefaultPrice(1, newPrice);

        assertEq(edition.defaultPrice(1), newPrice);
        assertNotEq(edition.defaultPrice(1), currentPrice);
    }
}
