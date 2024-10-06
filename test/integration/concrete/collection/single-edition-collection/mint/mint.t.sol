// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { SingleEditionCollection } from "src/SingleEditionCollection.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { CollectionData, EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";
import { MAX_SINGLE_EDITION_COLLECTION_SIZE } from "src/libraries/ConstantsLib.sol";

contract Mint_SingleEditionCollection_Integration_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    address referrer;
    uint256 startingUserBalance;
    uint256 startingControllerBalanceCollectionAdmin;
    uint256 startingControllerBalanceReferrer;
    uint256 startingPlatformFeeBalance;

    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual override {
        CollectionBase.setUp();

        referrer = users.user_1;

        // cache starting balances
        startingUserBalance = mockUSDC.balanceOf(user);
        startingControllerBalanceCollectionAdmin = _getUserControllerBalance(collectionAdmin);
        startingControllerBalanceReferrer = _getUserControllerBalance(referrer);
        startingPlatformFeeBalance = controller.platformFeeBalance();
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully mints collection
    function test__Mint_SingleEditionCollection_TokensMintedToCollection() external {
        // get erc6551 account
        address erc6551account = _getERC6551AccountSingleEdition(address(singleEditionCollection), 1);

        // emit erc721 transfer event
        vm.expectEmit({ emitter: address(singleEditionCollection) });
        emit Transfer({ from: address(0), to: user, tokenId: 1 });

        // emit collection minted event
        vm.expectEmit({ emitter: address(singleEditionCollection) });
        emit EventsLib.CollectionMinted(1, user, erc6551account);

        // emit batch transfer event
        vm.expectEmit({ emitter: address(edition) });
        emit TransferBatch({
            operator: address(singleEditionCollection),
            from: address(0),
            to: erc6551account,
            ids: singleEditionCollectionIds,
            amounts: singleEditionCollectionQuantities
        });

        // mint
        vm.prank(user);
        singleEditionCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });

        assertEq(singleEditionCollection.ownerOf(1), user);
        assertEq(singleEditionCollection.totalSupply(), 1);
        assertEq(singleEditionCollection.balanceOf(user), 1);

        // assert balance - tba
        for (uint256 i = 1; i <= NUM_TOKENS_SINGLE_EDITION_COLLECTION; i++) {
            assertEq(edition.balanceOf(erc6551account, i), 1);
        }

        // assert total supply - edition
        for (uint256 i = 2; i <= NUM_TOKENS_SINGLE_EDITION_COLLECTION; i++) {
            // tokens were minted to edition owner on `add`
            assertEq(edition.totalSupply(i), 2);
        }

        // verify user balance
        assertEq(mockUSDC.balanceOf(user), startingUserBalance - SINGLE_EDITION_COLLECTION_PRICE);
        assertEq(
            _getUserControllerBalance(collectionAdmin),
            startingControllerBalanceCollectionAdmin + SINGLE_EDITION_COLLECTION_PRICE
        );
    }

    /// @dev successfully mints collection with platform fee
    function test__Mint_SingleEditionCollection_WithPlatformFee() external {
        // enable platform fee
        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        // calculate platform fee
        uint256 platformFee = (SINGLE_EDITION_COLLECTION_PRICE * PLATFORM_FEE) / 10_000;

        // mint
        vm.prank(user);
        singleEditionCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });

        assertEq(singleEditionCollection.ownerOf(1), user);
        assertEq(singleEditionCollection.totalSupply(), 1);
        assertEq(singleEditionCollection.balanceOf(user), 1);

        // verify balances
        assertEq(
            _getUserControllerBalance(collectionAdmin),
            startingControllerBalanceCollectionAdmin + SINGLE_EDITION_COLLECTION_PRICE - platformFee
        );
        assertEq(controller.platformFeeBalance(), startingPlatformFeeBalance + platformFee);
    }

    /// @dev successfully mints collection with referral
    function test__Mint_SingleEditionCollection_WithReferral() external {
        // calculate referral fee
        uint256 referralFee = (SINGLE_EDITION_COLLECTION_PRICE * REFERRAL_FEE) / 10_000;

        // mint
        vm.prank(user);
        singleEditionCollection.mint({ to: user, extension: address(0), referrer: referrer, data: "" });

        // verify balances
        assertEq(
            _getUserControllerBalance(collectionAdmin),
            startingControllerBalanceCollectionAdmin + SINGLE_EDITION_COLLECTION_PRICE - referralFee
        );
        assertEq(_getUserControllerBalance(referrer), startingControllerBalanceReferrer + referralFee);
    }

    /// @dev successfully mints collection with referral and platform fee
    function test__Mint_SingleEditionCollection_WithReferralAndPlatformFee() external {
        // enable platform fee
        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        // calculate referral fee
        uint256 referralFee = (SINGLE_EDITION_COLLECTION_PRICE * REFERRAL_FEE) / 10_000;

        // calculate platform fee
        uint256 platformFee = (SINGLE_EDITION_COLLECTION_PRICE * PLATFORM_FEE) / 10_000;

        // mint
        vm.prank(user);
        singleEditionCollection.mint({ to: user, extension: address(0), referrer: referrer, data: "" });

        // verify balances
        assertEq(
            _getUserControllerBalance(collectionAdmin),
            startingControllerBalanceCollectionAdmin + SINGLE_EDITION_COLLECTION_PRICE - referralFee - platformFee
        );
        assertEq(_getUserControllerBalance(referrer), startingControllerBalanceReferrer + referralFee);
        assertEq(controller.platformFeeBalance(), startingPlatformFeeBalance + platformFee);
    }

    /// @dev successfully mints using extension
    function test__Mint_SingleEditionCollection_WithExtension() external {
        // setup extension
        uint128 customPrice = 8 * 10 ** 5;
        bytes memory extensionParams =
            abi.encode(customPrice, uint40(block.timestamp), uint40(block.timestamp + 2 days));

        vm.prank(collectionAdmin);
        singleEditionCollection.setExtension(address(mockCollectionExtension), true, extensionParams);

        // mint
        vm.prank(user);
        singleEditionCollection.mint({
            to: user,
            extension: address(mockCollectionExtension),
            referrer: address(0),
            data: ""
        });

        assertEq(singleEditionCollection.ownerOf(1), user);
        assertEq(singleEditionCollection.totalSupply(), 1);
        assertEq(singleEditionCollection.balanceOf(user), 1);

        // verify balances
        assertEq(_getUserControllerBalance(collectionAdmin), startingControllerBalanceCollectionAdmin + customPrice);
        assertEq(mockUSDC.balanceOf(user), startingUserBalance - customPrice);
    }

    /// @dev mint maximum collection size
    function test__Mint_SingleEditionCollection_MaxSize() external {
        // new edition
        RouxEdition edition_ = _createEdition(creator);

        // new array
        uint256[] memory newItemIds = new uint256[](MAX_SINGLE_EDITION_COLLECTION_SIZE);

        for (uint256 i = 0; i < MAX_SINGLE_EDITION_COLLECTION_SIZE; i++) {
            (, newItemIds[i]) = _addToken(edition_);
        }

        // encode params
        CollectionData.SingleEditionCreateParams memory params = singleEditionCollectionParams;
        params.itemTarget = address(edition_);
        params.itemIds = newItemIds;

        // create single edition collection
        vm.prank(creator);
        SingleEditionCollection singleEditionCollection_ =
            SingleEditionCollection(collectionFactory.createSingle(params));

        vm.prank(creator);
        edition_.setCollection(address(singleEditionCollection_), true);

        // approve single edition collection
        _approveToken(address(singleEditionCollection_), user);

        // mint
        vm.prank(user);
        singleEditionCollection_.mint({ to: user, extension: address(0), referrer: address(0), data: "" });

        // verify balance
        assertEq(singleEditionCollection_.balanceOf(user), 1);
        assertEq(singleEditionCollection_.totalSupply(), 1);
        assertEq(singleEditionCollection_.ownerOf(1), user);
    }
}
