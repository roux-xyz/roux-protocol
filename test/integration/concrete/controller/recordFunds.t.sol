// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { ControllerBase } from "test/shared/ControllerBase.t.sol";
import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE, CURATOR_FEE } from "src/libraries/FeesLib.sol";

contract RecordFunds_Controller_Integration_Concrete_Test is ControllerBase, CollectionBase {
    function setUp() public override(ControllerBase, CollectionBase) {
        ControllerBase.setUp();
        CollectionBase.setUp();
    }

    /// @dev returns correct balance - after recording funds
    function test__RecordFunds_SingleEditionCollectionReferral() external {
        // cache starting balance
        uint256 startingControllerBalanceReferrer = _getUserControllerBalance(users.user_1);

        uint256 referralFee = (SINGLE_EDITION_COLLECTION_PRICE * REFERRAL_FEE) / 10_000;

        vm.prank(user);
        singleEditionCollection.mint({ to: user, extension: address(0), referrer: users.user_1, data: "" });

        assertEq(controller.balance(users.user_1), startingControllerBalanceReferrer + referralFee);
    }

    /// @dev successfully records funds on multi edition collection
    function test__RecordFunds_MultiEditionCollection() external {
        // cache starting balance of collection fee recipient
        address collectionFeeRecipient = multiEditionCollection.collectionFeeRecipient();
        uint256 startingControllerBalanceCollectionAdmin = _getUserControllerBalance(collectionFeeRecipient);

        // get multi edition collection price
        uint256 multiEditionCollectionPrice = multiEditionCollection.price();

        // calculate collection fee
        uint256 collectionFee = (multiEditionCollectionPrice * CURATOR_FEE) / 10_000;

        // record funds
        vm.prank(user);
        multiEditionCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });

        assertEq(controller.balance(collectionFeeRecipient), startingControllerBalanceCollectionAdmin + collectionFee);
    }

    /// @dev successfully records funds on multi edition collection with referral
    function test__RecordFunds_MultiEditionCollectionReferral() external {
        address referrer = users.user_1;

        // cache starting balance of collection fee recipient
        address collectionFeeRecipient = multiEditionCollection.collectionFeeRecipient();
        uint256 startingControllerBalanceCollectionAdmin = _getUserControllerBalance(collectionFeeRecipient);
        uint256 startingControllerBalanceReferrer = _getUserControllerBalance(referrer);

        // get multi edition collection price
        uint256 multiEditionCollectionPrice = multiEditionCollection.price();

        // calculate referral fee
        uint256 referralFee = (multiEditionCollectionPrice * REFERRAL_FEE) / 10_000;

        // calculate collection fee
        uint256 collectionFee = ((multiEditionCollectionPrice - referralFee) * CURATOR_FEE) / 10_000;

        // record funds
        vm.prank(user);
        multiEditionCollection.mint({ to: user, extension: address(0), referrer: users.user_1, data: "" });

        assertEq(controller.balance(collectionFeeRecipient), startingControllerBalanceCollectionAdmin + collectionFee);
        assertEq(controller.balance(referrer), startingControllerBalanceReferrer + referralFee);
    }
}
