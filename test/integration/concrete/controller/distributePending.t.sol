// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { ControllerBase } from "test/shared/ControllerBase.t.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

contract Disburse_Controller_Integration_Concrete_Test is ControllerBase {
    function setUp() public override {
        ControllerBase.setUp();
    }

    /// @dev distribute pending for single fork
    function test__DistributePending_Fork_1() external {
        // create fork
        (RouxEdition forkEdition, uint256 tokenId) = _createFork(edition, 1, users.creator_1);

        // approve fork
        _approveToken(address(forkEdition), user);

        // compute split
        (uint256 parentShare,) = _computeSplit(edition, tokenId, TOKEN_PRICE);

        // mint
        _mintToken(forkEdition, tokenId, user);

        // disburse pending from original edition
        controller.distributePending(address(edition), tokenId);

        // get funds recipient
        address fundsRecipient = controller.fundsRecipient(address(edition), 1);

        // check balances
        assertEq(controller.pending(address(edition), 1), 0);
        assertEq(controller.balance(fundsRecipient), parentShare);
    }

    /// @dev distribute pending for two forks
    function test__DistributePending_Fork_2() external {
        _test__distributePending(2);
    }

    /// @dev distribute pending for three forks
    function test__DistributePending_Fork_3() external {
        _test__distributePending(3);
    }

    /// @dev distribute pending for eight forks
    function test__DistributePending_Fork_8() external {
        _test__distributePending(8);
    }
}
