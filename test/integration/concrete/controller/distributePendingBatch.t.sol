// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

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

    function test__DistributePendingBatch_Fork_3() external {
        // create original edition and 3 forks
        RouxEdition[] memory editions = _createForks(3);

        // approve and mint on the last fork
        _approveToken(address(editions[3]), user);
        _mintToken(editions[3], 1, user);

        // create running balances array
        uint256[] memory runningBalances = new uint256[](creatorArray.length);

        // prepare arrays for batch disburse
        address[] memory editionAddresses = new address[](3);
        uint256[] memory tokenIds = new uint256[](3);

        for (uint256 i = 0; i < 3; i++) {
            editionAddresses[i] = address(editions[2 - i]); // 2nd fork, 1st fork, original
            tokenIds[i] = 1;
        }

        // compute expected splits + update running balances using _computeSplit and _getRecipientIndex
        // fork 3
        (uint256 parentShare2, uint256 childShare3) = _computeSplit(editions[2], 1, TOKEN_PRICE);
        address edition3recipient = controller.fundsRecipient(address(editions[3]), 1);
        runningBalances[_getRecipientIndex(edition3recipient, creatorArray)] += childShare3;

        // fork 2
        (uint256 parentShare1, uint256 childShare2) = _computeSplit(editions[1], 1, parentShare2);
        address edition2recipient = controller.fundsRecipient(address(editions[2]), 1);
        runningBalances[_getRecipientIndex(edition2recipient, creatorArray)] += childShare2;

        // fork 1
        (uint256 parentShare0, uint256 childShare1) = _computeSplit(editions[0], 1, parentShare1);
        address edition1recipient = controller.fundsRecipient(address(editions[1]), 1);
        runningBalances[_getRecipientIndex(edition1recipient, creatorArray)] += childShare1;

        // root
        address edition0recipient = controller.fundsRecipient(address(editions[0]), 1);
        runningBalances[_getRecipientIndex(edition0recipient, creatorArray)] += parentShare0;

        // call distributePendingBatch
        controller.distributePendingBatch(editionAddresses, tokenIds);

        // check balances and pending amounts
        for (uint256 i = 0; i < creatorArray.length; i++) {
            assertEq(controller.balance(creatorArray[i]), runningBalances[i], "final balance mismatch");
        }

        for (uint256 i = 0; i < editions.length; i++) {
            assertEq(controller.pending(address(editions[i]), 1), 0, "pending should be 0 for all editions");
        }

        // verify total balance matches the initial mint price
        uint256 totalBalance = childShare3 + childShare2 + childShare1 + parentShare0;
        assertEq(totalBalance, TOKEN_PRICE, "total balance should match initial mint price");
    }
}
