// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { ControllerBase } from "test/shared/ControllerBase.t.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

contract SetControllerData_Controller_Integration_Concrete_Test is ControllerBase {
    function setUp() public override {
        ControllerBase.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when funds recipient is zero
    function test__RevertWhen_SetController_FundsRecipientIsZero() external {
        defaultAddParams.fundsRecipient = address(0);

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.Controller_InvalidFundsRecipient.selector);
        edition.add(defaultAddParams);
    }

    /// @dev reverts when profit share is too high
    function test__RevertWhen_SetController_ProfitShareTooHigh() external {
        RouxEdition edition_ = _createEdition(creator);

        defaultAddParams.profitShare = 10_001;
        defaultAddParams.parentEdition = address(edition);
        defaultAddParams.parentTokenId = 1;

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.Controller_InvalidProfitShare.selector);
        edition_.add(defaultAddParams);
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev set controller data
    function test__AddToken_SetControllerData() external {
        (, uint256 tokenId) = _addToken(edition);

        assertEq(tokenId, 2);
        assertEq(controller.fundsRecipient(address(edition), tokenId), defaultAddParams.fundsRecipient);
        assertEq(controller.profitShare(address(edition), tokenId), PROFIT_SHARE);
    }

    /// @dev set funds recipient
    function test__SetFundsRecipient() external {
        address originalRecipient = controller.fundsRecipient(address(edition), 1);
        address newRecipient = users.user_1;

        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.FundsRecipientUpdated(address(edition), 1, newRecipient);

        vm.prank(creator);
        edition.updateFundsRecipient(1, newRecipient);

        assertEq(controller.fundsRecipient(address(edition), 1), newRecipient);
        assertNotEq(controller.fundsRecipient(address(edition), 1), originalRecipient);
    }

    /// @dev set profit share
    function test__SetProfitShare() external {
        uint256 originalProfitShare = controller.profitShare(address(edition), 1);
        uint16 newProfitShare = PROFIT_SHARE + 1;

        vm.expectEmit({ emitter: address(controller) });
        emit EventsLib.ProfitShareUpdated(address(edition), 1, newProfitShare);

        vm.prank(creator);
        edition.updateProfitShare(1, newProfitShare);

        assertEq(controller.profitShare(address(edition), 1), newProfitShare);
        assertNotEq(controller.profitShare(address(edition), 1), originalProfitShare);
    }
}
