// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";

contract DisableGate_RouxEdition_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* state                                       */
    /* -------------------------------------------- */
    EditionData.AddParams addParams;

    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();

        addParams = defaultAddParams;

        // approve mock usdc
        vm.prank(user);
        mockUSDC.approve(address(edition), type(uint256).max);
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when not owner
    function test__RevertWhen_DisableGate_NotOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.disableGate(1);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    // @dev successfully ungates mint
    function test__DisableGate() external {
        addParams.gate = true;
        RouxEdition edition_ = _createEdition(creator);

        vm.prank(creator);
        edition_.add(addParams);

        // verify gate is set
        assertEq(edition_.isGated(1), true);

        vm.prank(creator);
        edition_.disableGate(1);

        // verify gate is unset
        assertEq(edition_.isGated(1), false);

        // cache starting token balance
        uint256 startingBalance = edition.balanceOf(user, 1);

        // successful mint
        vm.prank(user);
        edition.mint({ to: user, id: 1, quantity: 1, extension: address(0), referrer: user, data: "" });

        assertEq(edition.balanceOf(user, 1), startingBalance + 1);
    }
}
