// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { ControllerBase } from "test/shared/ControllerBase.t.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

contract Attribution_Registry_Integration_Concrete_Test is ControllerBase {
    function setUp() public override {
        ControllerBase.setUp();
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /// @dev returns correct parent edition and token id
    function test__Attribution() external {
        (RouxEdition forkEdition, uint256 forkTokenId) = _createFork(edition, 1, creator);

        (address parentEdition, uint256 parentTokenId) = registry.attribution(address(forkEdition), forkTokenId);

        assertEq(parentEdition, address(edition));
        assertEq(parentTokenId, 1);
    }

    /// @dev returns correct parent edition and token id - two levels
    function test__Attribution_TwoForks() external {
        (RouxEdition forkEdition, uint256 forkTokenId) = _createFork(edition, 1, creator);
        (RouxEdition fork2Edition, uint256 fork2TokenId) = _createFork(forkEdition, forkTokenId, creator);

        (address parentEdition, uint256 parentTokenId) = registry.attribution(address(fork2Edition), fork2TokenId);

        assertEq(parentEdition, address(forkEdition));
        assertEq(parentTokenId, forkTokenId);
    }
}
