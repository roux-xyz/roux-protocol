// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract UpdateFundsRecipient_RouxEdition_Unit_Concrete_Test is BaseTest {
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
    function test__RevertWhen_UpdateFundsRecipient_NotOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.updateFundsRecipient(1, users.user_1);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates funds recipient
    function test__UpdateFundsRecipient() external useEditionAdmin(edition) {
        address originalRecipient = controller.fundsRecipient(address(edition), 1);
        address newRecipient = users.user_1;

        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.FundsRecipientUpdated(address(edition), 1, newRecipient);

        edition.updateFundsRecipient(1, newRecipient);

        assertEq(controller.fundsRecipient(address(edition), 1), newRecipient);
        assertNotEq(controller.fundsRecipient(address(edition), 1), originalRecipient);
    }
}
