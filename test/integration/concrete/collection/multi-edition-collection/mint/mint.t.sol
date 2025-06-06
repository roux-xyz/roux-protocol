// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { MultiEditionCollection } from "src/core/MultiEditionCollection.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { CollectionData, EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE, CURATOR_FEE } from "src/libraries/FeesLib.sol";
import { MAX_MULTI_EDITION_COLLECTION_SIZE } from "src/libraries/ConstantsLib.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ERC721 } from "solady/tokens/ERC721.sol";
import { ERC1155 } from "solady/tokens/ERC1155.sol";

contract Mint_MultiEditionCollection_Integration_Concrete_Test is CollectionBase {
    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    address referrer;
    uint256 startingUserBalance;
    uint256 startingBalanceCurator;
    uint256 startingControllerBalanceReferrer;
    uint256 startingPlatformFeeBalance;

    address edition1FundsRecipient;
    address edition2FundsRecipient;
    address edition3FundsRecipient;

    uint256 startingBalanceEdition1FundsRecipient;
    uint256 startingBalanceEdition2FundsRecipient;
    uint256 startingBalanceEdition3FundsRecipient;

    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual override {
        CollectionBase.setUp();

        referrer = users.user_1;

        // cache users
        edition1FundsRecipient = controller.fundsRecipient(address(multiEditionItemTargets[0]), 1);
        edition2FundsRecipient = controller.fundsRecipient(address(multiEditionItemTargets[1]), 1);
        edition3FundsRecipient = controller.fundsRecipient(address(multiEditionItemTargets[2]), 1);

        // cache starting balances
        startingUserBalance = mockUSDC.balanceOf(user);
        startingBalanceCurator = _getUserControllerBalance(curator);
        startingControllerBalanceReferrer = _getUserControllerBalance(referrer);
        startingPlatformFeeBalance = controller.platformFeeBalance();
        startingBalanceEdition1FundsRecipient = _getUserControllerBalance(edition1FundsRecipient);
        startingBalanceEdition2FundsRecipient = _getUserControllerBalance(edition2FundsRecipient);
        startingBalanceEdition3FundsRecipient = _getUserControllerBalance(edition3FundsRecipient);
    }

    /* -------------------------------------------- */
    /* reverts                                        */
    /* -------------------------------------------- */

    /// @dev reverts when user doesn't own all required tokens
    function test__RevertWhen_ConvertMintMissingTokens() external {
        // mint only first token to user
        vm.prank(creator);
        RouxEdition(multiEditionItemTargets[0]).adminMint(user, multiEditionItemIds[0], 1, "");

        // approve multi edition collection to transfer tokens
        for (uint256 i = 0; i < multiEditionItemTargets.length; i++) {
            vm.prank(user);
            RouxEdition(multiEditionItemTargets[i]).setApprovalForAll(address(multiEditionCollection), true);
        }

        // attempt convert mint
        vm.prank(user);
        vm.expectRevert(ERC1155.InsufficientBalance.selector);
        multiEditionCollection.convertMint(user);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully mints collection
    function test__Mint_MultiEditionCollection_TokensMintedToCollection() external {
        // get erc6551 account
        address erc6551account = _getERC6551AccountMultiEdition(address(multiEditionCollection), 1);

        // emit erc721 transfer event
        vm.expectEmit({ emitter: address(multiEditionCollection) });
        emit Transfer({ from: address(0), to: user, tokenId: 1 });

        // get total price
        uint256 totalPrice = multiEditionCollection.price();

        // calculate collection fee
        uint256 curatorFee = (totalPrice * CURATOR_FEE) / 10_000;

        uint256 edition1CollectionFee = RouxEdition(multiEditionItemTargets[0]).defaultPrice(1) * CURATOR_FEE / 10_000;
        uint256 edition2CollectionFee = RouxEdition(multiEditionItemTargets[1]).defaultPrice(1) * CURATOR_FEE / 10_000;
        uint256 edition3CollectionFee = RouxEdition(multiEditionItemTargets[2]).defaultPrice(1) * CURATOR_FEE / 10_000;

        // mint
        vm.prank(user);
        multiEditionCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });

        assertEq(multiEditionCollection.ownerOf(1), user);
        assertEq(multiEditionCollection.totalSupply(), 1);
        assertEq(multiEditionCollection.balanceOf(user), 1);

        // assert balances
        assertEq(RouxEdition(multiEditionItemTargets[0]).balanceOf(erc6551account, 1), 1);
        assertEq(RouxEdition(multiEditionItemTargets[1]).balanceOf(erc6551account, 1), 1);
        assertEq(RouxEdition(multiEditionItemTargets[2]).balanceOf(erc6551account, 1), 1);

        // assert total supply
        assertEq(RouxEdition(multiEditionItemTargets[0]).totalSupply(1), 2);
        assertEq(RouxEdition(multiEditionItemTargets[1]).totalSupply(1), 2);
        assertEq(RouxEdition(multiEditionItemTargets[2]).totalSupply(1), 2);

        // verify balances
        assertEq(mockUSDC.balanceOf(user), startingUserBalance - totalPrice);
        assertEq(_getUserControllerBalance(curator), startingBalanceCurator + curatorFee);
        assertEq(
            _getUserControllerBalance(edition1FundsRecipient),
            startingBalanceEdition1FundsRecipient + RouxEdition(multiEditionItemTargets[0]).defaultPrice(1)
                - edition1CollectionFee
        );
        assertEq(
            _getUserControllerBalance(edition2FundsRecipient),
            startingBalanceEdition2FundsRecipient + RouxEdition(multiEditionItemTargets[1]).defaultPrice(1)
                - edition2CollectionFee
        );
        assertEq(
            _getUserControllerBalance(edition3FundsRecipient),
            startingBalanceEdition3FundsRecipient + RouxEdition(multiEditionItemTargets[2]).defaultPrice(1)
                - edition3CollectionFee
        );
    }

    /// @dev successfully mints collection with mixed editions, standard and community
    function test__Mint_MultiEditionCollection_MixedEditions_StandardAndCommunity() external {
        // get erc6551 account
        address erc6551account = _getERC6551AccountMultiEdition(address(mixedMultiEditionCollection), 1);

        // emit erc721 transfer event
        vm.expectEmit({ emitter: address(mixedMultiEditionCollection) });
        emit Transfer({ from: address(0), to: user, tokenId: 1 });

        // get total price
        uint256 totalPrice = mixedMultiEditionCollection.price();

        // calculate collection fee
        uint256 curatorFee = (totalPrice * CURATOR_FEE) / 10_000;

        uint256 edition1CollectionFee =
            RouxEdition(mixedMultiEditionItemTargets[0]).defaultPrice(1) * CURATOR_FEE / 10_000;
        uint256 edition2CollectionFee =
            RouxEdition(mixedMultiEditionItemTargets[1]).defaultPrice(1) * CURATOR_FEE / 10_000;
        uint256 edition3CollectionFee =
            RouxEdition(mixedMultiEditionItemTargets[2]).defaultPrice(1) * CURATOR_FEE / 10_000;

        // mint
        vm.prank(user);
        mixedMultiEditionCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });

        assertEq(mixedMultiEditionCollection.ownerOf(1), user);
        assertEq(mixedMultiEditionCollection.totalSupply(), 1);
        assertEq(mixedMultiEditionCollection.balanceOf(user), 1);

        // assert balances
        assertEq(RouxEdition(mixedMultiEditionItemTargets[0]).balanceOf(erc6551account, 1), 1);
        assertEq(RouxEdition(mixedMultiEditionItemTargets[1]).balanceOf(erc6551account, 1), 1);
        assertEq(RouxEdition(mixedMultiEditionItemTargets[2]).balanceOf(erc6551account, 1), 1);

        // assert total supply
        assertEq(RouxEdition(mixedMultiEditionItemTargets[0]).totalSupply(1), 2);
        assertEq(RouxEdition(mixedMultiEditionItemTargets[1]).totalSupply(1), 2);
        assertEq(RouxEdition(mixedMultiEditionItemTargets[2]).totalSupply(1), 2);

        // verify balances
        assertEq(mockUSDC.balanceOf(user), startingUserBalance - totalPrice);
        assertEq(_getUserControllerBalance(curator), startingBalanceCurator + curatorFee);
        assertEq(
            _getUserControllerBalance(edition1FundsRecipient),
            startingBalanceEdition1FundsRecipient + RouxEdition(mixedMultiEditionItemTargets[0]).defaultPrice(1)
                - edition1CollectionFee
        );
        assertEq(
            _getUserControllerBalance(edition2FundsRecipient),
            startingBalanceEdition2FundsRecipient + RouxEdition(mixedMultiEditionItemTargets[1]).defaultPrice(1)
                - edition2CollectionFee
        );
        assertEq(
            _getUserControllerBalance(edition3FundsRecipient),
            startingBalanceEdition3FundsRecipient + RouxEdition(mixedMultiEditionItemTargets[2]).defaultPrice(1)
                - edition3CollectionFee
        );
    }

    /// @dev successfully mints collection with platform fee
    function test__Mint_MultiEditionCollection_WithPlatformFee() external {
        // enable platform fee
        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        // get total price
        uint256 totalPrice = multiEditionCollection.price();

        // get collection fee
        uint256 curatorFee = (totalPrice * CURATOR_FEE) / 10_000;
        uint256 platformFee = ((totalPrice - curatorFee) * PLATFORM_FEE) / 10_000;

        // mint
        vm.prank(user);
        multiEditionCollection.mint({ to: user, extension: address(0), referrer: address(0), data: "" });

        // verify balance
        assertEq(controller.platformFeeBalance(), startingPlatformFeeBalance + platformFee);
    }

    /// @dev successfully mints collection with referral
    function test__Mint_MultiEditionCollection_WithReferral() external {
        // get total price
        uint256 totalPrice = multiEditionCollection.price();

        // get referral fee
        uint256 edition1ReferralFee = RouxEdition(multiEditionItemTargets[0]).defaultPrice(1) * REFERRAL_FEE / 10_000;
        uint256 edition2ReferralFee = RouxEdition(multiEditionItemTargets[1]).defaultPrice(1) * REFERRAL_FEE / 10_000;
        uint256 edition3ReferralFee = RouxEdition(multiEditionItemTargets[2]).defaultPrice(1) * REFERRAL_FEE / 10_000;

        // get collection fee
        uint256 curatorFee =
            ((totalPrice - edition1ReferralFee - edition2ReferralFee - edition3ReferralFee) * CURATOR_FEE) / 10_000;

        // get collection fee
        uint256 edition1CollectionFee =
            (RouxEdition(multiEditionItemTargets[0]).defaultPrice(1) - edition1ReferralFee) * CURATOR_FEE / 10_000;
        uint256 edition2CollectionFee =
            (RouxEdition(multiEditionItemTargets[1]).defaultPrice(1) - edition2ReferralFee) * CURATOR_FEE / 10_000;
        uint256 edition3CollectionFee =
            (RouxEdition(multiEditionItemTargets[2]).defaultPrice(1) - edition3ReferralFee) * CURATOR_FEE / 10_000;

        // mint
        vm.prank(user);
        multiEditionCollection.mint({ to: user, extension: address(0), referrer: referrer, data: "" });

        // verify balances
        assertEq(mockUSDC.balanceOf(user), startingUserBalance - totalPrice);
        assertEq(_getUserControllerBalance(curator), startingBalanceCurator + curatorFee);
        assertEq(
            _getUserControllerBalance(edition1FundsRecipient),
            startingBalanceEdition1FundsRecipient + RouxEdition(multiEditionItemTargets[0]).defaultPrice(1)
                - edition1CollectionFee - edition1ReferralFee
        );
        assertEq(
            _getUserControllerBalance(edition2FundsRecipient),
            startingBalanceEdition2FundsRecipient + RouxEdition(multiEditionItemTargets[1]).defaultPrice(1)
                - edition2CollectionFee - edition2ReferralFee
        );
        assertEq(
            _getUserControllerBalance(edition3FundsRecipient),
            startingBalanceEdition3FundsRecipient + RouxEdition(multiEditionItemTargets[2]).defaultPrice(1)
                - edition3CollectionFee - edition3ReferralFee
        );
    }

    /// @dev successfully mints collection with referral and platform fee
    function test__Mint_MultiEditionCollection_WithReferralAndPlatformFee() external {
        // enable platform fee
        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        // get total price
        uint256 totalPrice = multiEditionCollection.price();

        // calculate fees
        uint256 referralFee = (totalPrice * REFERRAL_FEE) / 10_000;
        uint256 curatorFee = ((totalPrice - referralFee) * CURATOR_FEE) / 10_000;
        uint256 platformFee = ((totalPrice - curatorFee - referralFee) * PLATFORM_FEE) / 10_000;

        // get referral fee
        uint256 edition1ReferralFee = RouxEdition(multiEditionItemTargets[0]).defaultPrice(1) * REFERRAL_FEE / 10_000;
        uint256 edition2ReferralFee = RouxEdition(multiEditionItemTargets[1]).defaultPrice(1) * REFERRAL_FEE / 10_000;
        uint256 edition3ReferralFee = RouxEdition(multiEditionItemTargets[2]).defaultPrice(1) * REFERRAL_FEE / 10_000;

        // get collection fee
        uint256 edition1CollectionFee =
            (RouxEdition(multiEditionItemTargets[0]).defaultPrice(1) - edition1ReferralFee) * CURATOR_FEE / 10_000;
        uint256 edition2CollectionFee =
            (RouxEdition(multiEditionItemTargets[1]).defaultPrice(1) - edition2ReferralFee) * CURATOR_FEE / 10_000;
        uint256 edition3CollectionFee =
            (RouxEdition(multiEditionItemTargets[2]).defaultPrice(1) - edition3ReferralFee) * CURATOR_FEE / 10_000;

        // get platform fee
        uint256 edition1PlatformFee = (
            RouxEdition(multiEditionItemTargets[0]).defaultPrice(1) - edition1CollectionFee - edition1ReferralFee
        ) * PLATFORM_FEE / 10_000;
        uint256 edition2PlatformFee = (
            RouxEdition(multiEditionItemTargets[1]).defaultPrice(1) - edition2CollectionFee - edition2ReferralFee
        ) * PLATFORM_FEE / 10_000;
        uint256 edition3PlatformFee = (
            RouxEdition(multiEditionItemTargets[2]).defaultPrice(1) - edition3CollectionFee - edition3ReferralFee
        ) * PLATFORM_FEE / 10_000;

        // mint
        vm.prank(user);
        multiEditionCollection.mint({ to: user, extension: address(0), referrer: referrer, data: "" });

        // verify balances
        assertEq(_getUserControllerBalance(referrer), startingControllerBalanceReferrer + referralFee);
        assertEq(controller.platformFeeBalance(), startingPlatformFeeBalance + platformFee);

        assertEq(
            _getUserControllerBalance(edition1FundsRecipient),
            startingBalanceEdition1FundsRecipient + RouxEdition(multiEditionItemTargets[0]).defaultPrice(1)
                - edition1CollectionFee - edition1ReferralFee - edition1PlatformFee
        );
        assertEq(
            _getUserControllerBalance(edition2FundsRecipient),
            startingBalanceEdition2FundsRecipient + RouxEdition(multiEditionItemTargets[1]).defaultPrice(1)
                - edition2CollectionFee - edition2ReferralFee - edition2PlatformFee
        );
        assertEq(
            _getUserControllerBalance(edition3FundsRecipient),
            startingBalanceEdition3FundsRecipient + RouxEdition(multiEditionItemTargets[2]).defaultPrice(1)
                - edition3CollectionFee - edition3ReferralFee - edition3PlatformFee
        );
    }

    /// @dev mint maximum collection size
    function test__Mint_MultiEditionCollection_MaxSize() external {
        // create editions
        RouxEdition[] memory editions = new RouxEdition[](MAX_MULTI_EDITION_COLLECTION_SIZE);
        uint256[] memory tokenIds = new uint256[](MAX_MULTI_EDITION_COLLECTION_SIZE);

        for (uint256 i = 0; i < MAX_MULTI_EDITION_COLLECTION_SIZE; i++) {
            editions[i] = _createEdition(creator);
            (, tokenIds[i]) = _addToken(editions[i]);
        }

        // create multi edition collection
        MultiEditionCollection multiEditionCollection_ = _createMultiEditionCollection(editions, tokenIds);

        // approve multi edition collection
        _approveToken(address(multiEditionCollection_), user);

        // mint
        vm.prank(user);
        multiEditionCollection_.mint({ to: user, extension: address(0), referrer: address(0), data: "" });

        // verify balance
        assertEq(multiEditionCollection_.balanceOf(user), 1);
        assertEq(multiEditionCollection_.totalSupply(), 1);
        assertEq(multiEditionCollection_.ownerOf(1), user);
    }

    /// @dev successfully converts owned tokens to collection
    function test__ConvertMint_MultiEditionCollection() external {
        // get erc6551 account that will be created
        address erc6551account = _getERC6551AccountMultiEdition(address(multiEditionCollection), 1);

        // mint individual tokens to user first
        for (uint256 i = 0; i < multiEditionItemTargets.length; i++) {
            vm.prank(RouxEdition(multiEditionItemTargets[i]).owner());
            RouxEdition(multiEditionItemTargets[i]).adminMint(user, multiEditionItemIds[i], 1, "");
        }

        // approve multi edition collection to transfer tokens
        for (uint256 i = 0; i < multiEditionItemTargets.length; i++) {
            vm.prank(user);
            RouxEdition(multiEditionItemTargets[i]).setApprovalForAll(address(multiEditionCollection), true);
        }

        // emit erc1155 transfer event for collection NFT
        vm.expectEmit({ emitter: address(multiEditionCollection) });
        emit Transfer({ from: address(0), to: user, tokenId: 1 });

        // convert mint
        vm.prank(user);
        multiEditionCollection.convertMint(user);

        // assert collection token minted correctly
        assertEq(multiEditionCollection.ownerOf(1), user);
        assertEq(multiEditionCollection.totalSupply(), 1);
        assertEq(multiEditionCollection.balanceOf(user), 1);

        // assert tokens transferred to TBA
        for (uint256 i = 0; i < multiEditionItemTargets.length; i++) {
            assertEq(RouxEdition(multiEditionItemTargets[i]).balanceOf(erc6551account, multiEditionItemIds[i]), 1);
        }
    }
}
