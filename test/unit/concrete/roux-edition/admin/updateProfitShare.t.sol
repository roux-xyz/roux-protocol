// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract UpdateProfitShare_RouxEdition_Unit_Concrete_Test is BaseTest {
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
    function test__RevertWhen_UpdateProfitShare_NotOwner() external {
        vm.prank(users.user_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.updateProfitShare(1, PROFIT_SHARE + 1);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates profit share
    function test__UpdateProfitShare() external useEditionAdmin(edition) {
        uint256 originalProfitShare = controller.profitShare(address(edition), 1);
        uint16 newProfitShare = PROFIT_SHARE + 1;

        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.ProfitShareUpdated(address(edition), 1, newProfitShare);

        edition.updateProfitShare(1, newProfitShare);

        assertEq(controller.profitShare(address(edition), 1), newProfitShare);
        assertNotEq(controller.profitShare(address(edition), 1), originalProfitShare);
    }
}
