// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { IController } from "src/interfaces/IController.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import "forge-std/console.sol";

contract ControllerTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    // --------------------------------------------
    // reverts
    // --------------------------------------------

    function test__RevertWhen_SetController_FundsRecipientIsZero() external {
        vm.prank(users.creator_0);
        vm.expectRevert(IController.InvalidFundsRecipient.selector);
        edition.add(
            TEST_TOKEN_URI,
            users.creator_0,
            TEST_TOKEN_MAX_SUPPLY,
            address(0),
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter),
            optionalMintParams
        );
    }

    function test__RevertWhen_SetController_ProfitShareTooHigh() external {
        // modify default controller data
        defaultControllerData.fundsRecipient = address(0);

        vm.prank(users.creator_0);
        vm.expectRevert(IController.InvalidProfitShare.selector);
        edition.add(
            TEST_TOKEN_URI,
            users.creator_0,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_0,
            10_001,
            address(0),
            0,
            address(editionMinter),
            optionalMintParams
        );
    }

    function test__RevertWhen_SetController_ProfitShareDecreased() external {
        // modify default controller data
        defaultControllerData.fundsRecipient = address(0);

        vm.startPrank(users.creator_0);
        uint256 tokenId = edition.add(
            TEST_TOKEN_URI,
            users.creator_0,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_0,
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter),
            optionalMintParams
        );

        vm.expectRevert(IController.InvalidProfitShare.selector);
        edition.updateControllerData(tokenId, users.creator_0, TEST_PROFIT_SHARE - 1);
    }

    function test__RevertWhen_EnablePlatformFee_OnlyOwner() external {
        // attempt to enable minting
        vm.prank(users.creator_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.enablePlatformFee(true);
    }

    function test__RevertWhen_UpgradeToAndCall_OnlyOwner() external {
        // attempt to upgrade to and call
        vm.prank(users.creator_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        controller.upgradeToAndCall(address(edition), "");
    }

    function test__RevertWhen_WithdrawBatch_DifferentFundsRecipients() external {
        // add token with different funds recipient
        vm.prank(users.creator_0);
        edition.add(
            TEST_TOKEN_URI,
            users.creator_0,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_1, // different funds recipient
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter),
            optionalMintParams
        );

        // mint
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");

        // mint 2nd token
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 2, 1, "");

        // check balance
        assertEq(controller.balance(address(edition), 1), TEST_TOKEN_PRICE);
        assertEq(controller.balance(address(edition), 2), TEST_TOKEN_PRICE);

        // set up token ids
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        // withdraw
        vm.prank(users.creator_0);
        vm.expectRevert(IController.InvalidFundsRecipient.selector);
        controller.withdrawBatch(address(edition), tokenIds);
    }

    // --------------------------------------------
    // view
    // --------------------------------------------

    function test__Owner() external {
        assertEq(controller.owner(), address(users.deployer));
    }

    function test__ProfitShare() external {
        assertEq(controller.profitShare(address(edition), 1), TEST_PROFIT_SHARE);
    }

    function test__FundsRecipient() external {
        assertEq(controller.fundsRecipient(address(edition), 1), users.creator_0);
    }

    // --------------------------------------------
    // write
    // --------------------------------------------

    function test__AddToken() external {
        // create edition instance
        vm.startPrank(users.creator_1);

        // create edition instance
        bytes memory params = abi.encode(TEST_CONTRACT_URI);
        RouxEdition edition1 = RouxEdition(factory.create(params));

        // expect the relevant event to be emitted
        vm.expectEmit({ emitter: address(edition1) });
        emit TokenAdded({ id: 1 });

        edition1.add(
            TEST_TOKEN_URI,
            users.creator_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_1,
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter),
            optionalMintParams
        );
        vm.stopPrank();

        // check token data
        assertEq(edition1.currentToken(), 1);

        // get attribution
        (address parentEdition, uint256 parentTokenId) = registry.attribution(address(edition1), 1);

        // verify attribution
        assertEq(parentEdition, address(0));
        assertEq(parentTokenId, 0);
    }

    function test__Mint_BalanceUpdated() external {
        // expect disbursement to be emitted
        vm.expectEmit({ emitter: address(controller) });
        emit Disbursement({ edition: address(edition), tokenId: 1, amount: TEST_TOKEN_PRICE });

        // mint
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");

        // check balance
        assertEq(controller.balance(address(edition), 1), TEST_TOKEN_PRICE);
    }

    function test__AddToken_WithAttribution() external {
        // create edition instance
        vm.startPrank(users.creator_1);

        // create edition instance
        bytes memory params = abi.encode(TEST_CONTRACT_URI);
        RouxEdition edition1 = RouxEdition(factory.create(params));

        // expect the relevant event to be emitted
        vm.expectEmit({ emitter: address(edition1) });
        emit TokenAdded({ id: 1 });

        edition1.add(
            TEST_TOKEN_URI,
            users.creator_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_1,
            TEST_PROFIT_SHARE,
            address(edition),
            1,
            address(editionMinter),
            optionalMintParams
        );
        vm.stopPrank();

        // check token data
        assertEq(edition1.currentToken(), 1);

        // get attribution
        (address parentEdition, uint256 parentTokenId) = registry.attribution(address(edition1), 1);

        // verify attribution
        assertEq(parentEdition, address(edition));
        assertEq(parentTokenId, 1);
    }

    function test__Mint_WithAttribution_DepthOf1_BalancesUpdated() external {
        // create edition instance
        vm.startPrank(users.creator_1);

        // create edition instance
        bytes memory params = abi.encode(TEST_CONTRACT_URI);
        RouxEdition edition1 = RouxEdition(factory.create(params));

        // create forked token with attribution
        edition1.add(
            TEST_TOKEN_URI,
            users.creator_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_1,
            TEST_PROFIT_SHARE,
            address(edition),
            1,
            address(editionMinter),
            optionalMintParams
        );
        vm.stopPrank();

        // compute split
        uint256 profitShare = controller.profitShare(address(edition), 1);
        uint256 parentShare = (TEST_TOKEN_PRICE * (10_000 - profitShare)) / 10_000;
        uint256 childShare = TEST_TOKEN_PRICE - parentShare;

        // expect disbursement to be emitted
        vm.expectEmit({ emitter: address(controller) });
        emit Disbursement({ edition: address(edition1), tokenId: 1, amount: childShare });

        // expect pending to be emitted
        vm.expectEmit({ emitter: address(controller) });
        emit PendingUpdated({
            edition: address(edition1),
            tokenId: 1,
            parent: address(edition),
            parentTokenId: 1,
            amount: parentShare
        });

        // mint
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition1), 1, 1, "");

        // check balance
        assertEq(controller.balance(address(edition1), 1), childShare);
        assertEq(controller.pending(address(edition), 1), parentShare);
    }

    function test__Withdraw() external {
        // cache starting balance
        uint256 creator0StartingBalance = address(users.creator_0).balance;

        // mint
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");

        // check balance
        assertEq(controller.balance(address(edition), 1), TEST_TOKEN_PRICE);

        // expect withdrawal to be emitted
        vm.expectEmit({ emitter: address(controller) });
        emit Withdrawn({ edition: address(edition), tokenId: 1, to: users.creator_0, amount: TEST_TOKEN_PRICE });

        // withdraw
        controller.withdraw(address(edition), 1);

        // check balance
        assertEq(address(users.creator_0).balance, creator0StartingBalance + TEST_TOKEN_PRICE);
    }

    function test__Withdraw_WithAttribution_DepthOf1() external {
        // cache starting balances
        uint256 creator0StartingBalance = address(users.creator_0).balance;
        uint256 creator1StartingBalance = address(users.creator_1).balance;

        // prank
        vm.startPrank(users.creator_1);

        // create edition instance
        bytes memory params = abi.encode(TEST_CONTRACT_URI);
        RouxEdition edition1 = RouxEdition(factory.create(params));

        // create forked token with attribution
        edition1.add(
            TEST_TOKEN_URI,
            users.creator_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_1,
            TEST_PROFIT_SHARE,
            address(edition),
            1,
            address(editionMinter),
            optionalMintParams
        );
        vm.stopPrank();

        // compute split
        uint256 profitShare = controller.profitShare(address(edition), 1);
        uint256 parentShare = (TEST_TOKEN_PRICE * (10_000 - profitShare)) / 10_000;
        uint256 childShare = TEST_TOKEN_PRICE - parentShare;

        // mint
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition1), 1, 1, "");

        // check balance
        assertEq(controller.balance(address(edition1), 1), childShare);
        assertEq(controller.pending(address(edition), 1), parentShare);

        // expect withdrawal to be emitted
        vm.expectEmit({ emitter: address(controller) });
        emit Withdrawn({ edition: address(edition1), tokenId: 1, to: users.creator_1, amount: childShare });

        // withdraw
        controller.withdraw(address(edition1), 1);

        // check balances
        assertEq(address(users.creator_1).balance, creator1StartingBalance + childShare);

        // expect withdrawal to be emitted
        vm.expectEmit({ emitter: address(controller) });
        emit Withdrawn({ edition: address(edition), tokenId: 1, to: users.creator_0, amount: parentShare });

        // withdraw
        controller.withdraw(address(edition), 1);

        // check balances
        assertEq(address(users.creator_0).balance, creator0StartingBalance + parentShare);
    }

    function test__WithdrawBatch() external {
        // cache starting balances
        uint256 creator0StartingBalance = address(users.creator_0).balance;

        // add token
        vm.prank(users.creator_0);
        edition.add(
            TEST_TOKEN_URI,
            users.creator_0,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_0,
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter),
            optionalMintParams
        );

        // mint
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");

        // mint 2nd token
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 2, 1, "");

        // check balance
        assertEq(controller.balance(address(edition), 1), TEST_TOKEN_PRICE);
        assertEq(controller.balance(address(edition), 2), TEST_TOKEN_PRICE);

        // expect withdrawal to be emitted
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        vm.expectEmit({ emitter: address(controller) });
        emit WithdrawnBatch({
            edition: address(edition),
            tokenIds: tokenIds,
            to: users.creator_0,
            amount: TEST_TOKEN_PRICE * 2
        });

        // withdraw
        controller.withdrawBatch(address(edition), tokenIds);

        // check balances
        assertEq(address(users.creator_0).balance, creator0StartingBalance + TEST_TOKEN_PRICE * 2);
    }

    function test__WithdrawBatch_WithAttribution_DepthOf1() external {
        // cache starting balances
        uint256 creator1StartingBalance = address(users.creator_1).balance;

        // prank
        vm.startPrank(users.creator_1);

        // create edition instance
        bytes memory params = abi.encode(TEST_CONTRACT_URI);
        RouxEdition edition1 = RouxEdition(factory.create(params));

        // create forked token with attribution

        edition1.add(
            TEST_TOKEN_URI,
            users.creator_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_1,
            TEST_PROFIT_SHARE,
            address(edition),
            1,
            address(editionMinter),
            optionalMintParams
        );

        vm.stopPrank();

        // compute split
        uint256 profitShare = controller.profitShare(address(edition), 1);
        uint256 parentShare = (TEST_TOKEN_PRICE * (10_000 - profitShare)) / 10_000;
        uint256 childShare = TEST_TOKEN_PRICE - parentShare;

        // mint
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition1), 1, 1, "");

        // check balance
        assertEq(controller.balance(address(edition1), 1), childShare);
        assertEq(controller.pending(address(edition), 1), parentShare);

        // create a 2nd token
        vm.prank(users.creator_1);
        edition1.add(
            TEST_TOKEN_URI,
            users.creator_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_1,
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter),
            optionalMintParams
        );

        // mint 2nd token
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition1), 2, 1, "");

        // expect withdrawal to be emitted
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        vm.expectEmit({ emitter: address(controller) });
        emit WithdrawnBatch({
            edition: address(edition1),
            tokenIds: tokenIds,
            to: users.creator_1,
            amount: childShare + TEST_TOKEN_PRICE
        });

        // withdraw
        controller.withdrawBatch(address(edition1), tokenIds);

        // check balances
        assertEq(address(users.creator_1).balance, creator1StartingBalance + childShare + TEST_TOKEN_PRICE);
    }

    function test__Withdraw_WithAttribution_DepthOf3() external {
        // prank
        vm.startPrank(users.creator_1);

        // create edition instance
        bytes memory params = abi.encode(TEST_CONTRACT_URI);
        RouxEdition edition1 = RouxEdition(factory.create(params));

        // create forked token with attribution
        uint256 tokenId = edition1.add(
            TEST_TOKEN_URI,
            users.creator_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_1,
            TEST_PROFIT_SHARE,
            address(edition),
            1,
            address(editionMinter),
            optionalMintParams
        );
        vm.stopPrank();

        (address parentEdition, uint256 parentTokenId) = registry.attribution(address(edition1), 1);

        assertEq(parentEdition, address(edition));
        assertEq(parentTokenId, 1);

        // create forked token from the fork with attribution
        vm.prank(users.creator_0);

        uint256 tokenId2 = edition.add(
            TEST_TOKEN_URI,
            users.creator_0,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_0,
            TEST_PROFIT_SHARE,
            address(edition1),
            1,
            address(editionMinter),
            optionalMintParams
        );

        // cache starting balances
        uint256 balance0 = address(users.creator_0).balance;
        uint256 balance1 = address(users.creator_1).balance;

        // mint 2nd fork
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), tokenId2, 1, "");
        assertEq(edition.balanceOf(users.user_0, tokenId2), 1);

        // calculate expected splits
        uint256 edition2CreatorSplit = (TEST_TOKEN_PRICE * TEST_PROFIT_SHARE) / 10_000;
        uint256 edition1EarnedSplit = (TEST_TOKEN_PRICE * (10_000 - TEST_PROFIT_SHARE)) / 10_000;
        uint256 edition1CreatorSplit = (edition1EarnedSplit * TEST_PROFIT_SHARE) / 10_000;
        uint256 rootSplit = (edition1EarnedSplit * (10_000 - TEST_PROFIT_SHARE)) / 10_000;

        // withdraw from fork2, tokenId2
        vm.prank(users.creator_0);
        uint256 withdrawalAmount = controller.withdraw(address(edition), tokenId2);
        assertEq(withdrawalAmount, edition2CreatorSplit);

        // withdraw from fork1
        vm.prank(users.creator_1);
        uint256 withdrawalAmount2 = controller.withdraw(address(edition1), tokenId);
        assertEq(withdrawalAmount2, edition1CreatorSplit);

        // withdraw from root
        vm.prank(users.creator_0);
        uint256 withdrawalAmount3 = controller.withdraw(address(edition), 1);
        assertEq(withdrawalAmount3, rootSplit);

        // verify balances
        assertEq(address(users.creator_0).balance, balance0 + rootSplit + edition2CreatorSplit);
        assertEq(address(users.creator_1).balance, balance1 + edition1CreatorSplit);
    }

    function test__WithdrawBatch_WithAttribution_DepthOf3() external {
        // prank
        vm.prank(users.creator_0);

        // create second token in root edition
        uint256 rootTokenId2 = edition.add(
            TEST_TOKEN_URI,
            users.creator_0,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_0,
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter),
            optionalMintParams
        );

        // prank
        vm.startPrank(users.creator_1);

        // create edition instance
        bytes memory params = abi.encode(TEST_CONTRACT_URI);
        RouxEdition edition1 = RouxEdition(factory.create(params));

        // create forked token with attribution
        uint256 forkOneTokenId1 = edition1.add(
            TEST_TOKEN_URI,
            users.creator_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_1,
            TEST_PROFIT_SHARE,
            address(edition), // edition token 1
            1,
            address(editionMinter),
            optionalMintParams
        );

        // create forked token with attribution from 2nd token
        uint256 forkOneTokenId2 = edition1.add(
            TEST_TOKEN_URI,
            users.creator_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_1,
            TEST_PROFIT_SHARE,
            address(edition), // edition token 2
            rootTokenId2,
            address(editionMinter),
            optionalMintParams
        );

        vm.stopPrank();

        // verify attribution
        (address parentEdition, uint256 parentTokenId) = registry.attribution(address(edition1), forkOneTokenId1);
        assertEq(parentEdition, address(edition));
        assertEq(parentTokenId, 1);

        (address parentEdition2, uint256 parentTokenId2) = registry.attribution(address(edition1), forkOneTokenId2);
        assertEq(parentEdition2, address(edition));
        assertEq(parentTokenId2, rootTokenId2);

        // add user_1 to allowlist
        vm.prank(users.deployer);
        address[] memory allowlist = new address[](1);
        allowlist[0] = address(users.user_1);
        factory.addAllowlist(allowlist);

        // create forked token from the fork with attribution
        vm.startPrank(users.user_1);

        // create another edition instance
        RouxEdition edition2 = RouxEdition(factory.create(params));

        // add forked token
        uint256 forkTwoTokenId1 = edition2.add(
            TEST_TOKEN_URI,
            users.user_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.user_1,
            TEST_PROFIT_SHARE,
            address(edition1),
            forkOneTokenId1,
            address(editionMinter),
            optionalMintParams
        );

        // add second forked token
        uint256 forkTwoTokenId2 = edition2.add(
            TEST_TOKEN_URI,
            users.user_1,
            TEST_TOKEN_MAX_SUPPLY,
            users.user_1,
            TEST_PROFIT_SHARE,
            address(edition1),
            forkOneTokenId2,
            address(editionMinter),
            optionalMintParams
        );

        // verify attribution
        (address parentEdition3, uint256 parentTokenId3) = registry.attribution(address(edition2), forkTwoTokenId1);
        assertEq(parentEdition3, address(edition1));
        assertEq(parentTokenId3, forkOneTokenId1);

        (address parentEdition4, uint256 parentTokenId4) = registry.attribution(address(edition2), forkTwoTokenId2);
        assertEq(parentEdition4, address(edition1));
        assertEq(parentTokenId4, forkOneTokenId2);

        // cache starting balances
        uint256 balance0 = address(users.creator_0).balance; // original creator
        uint256 balance1 = address(users.creator_1).balance; // 1st fork creator
        uint256 balanceUser1 = address(users.user_1).balance; // 2nd fork creator

        vm.stopPrank();

        // mint 2nd fork tokens
        vm.startPrank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition2), forkTwoTokenId1, 1, "");
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition2), forkTwoTokenId2, 1, "");
        vm.stopPrank();

        assertEq(edition2.balanceOf(users.user_0, forkTwoTokenId1), 1);
        assertEq(edition2.balanceOf(users.user_0, forkTwoTokenId2), 1);

        // calculate expected splits
        uint256 edition2CreatorSplit = (TEST_TOKEN_PRICE * TEST_PROFIT_SHARE) / 10_000;
        uint256 edition1EarnedSplit = (TEST_TOKEN_PRICE * (10_000 - TEST_PROFIT_SHARE)) / 10_000;
        uint256 edition1CreatorSplit = (edition1EarnedSplit * TEST_PROFIT_SHARE) / 10_000;
        uint256 rootSplit = (edition1EarnedSplit * (10_000 - TEST_PROFIT_SHARE)) / 10_000;

        // verify balances
        assertEq(controller.balance(address(edition2), forkTwoTokenId1), edition2CreatorSplit, "fork2 creator split 1");
        assertEq(controller.balance(address(edition2), forkTwoTokenId2), edition2CreatorSplit, "fork2 creator split 2");
        assertEq(controller.pending(address(edition1), forkOneTokenId1), edition1EarnedSplit, "fork1 earned split 1");
        assertEq(controller.pending(address(edition1), forkOneTokenId2), edition1EarnedSplit, "fork1 earned split 2");

        uint256[] memory fork2TokenIds = new uint256[](2);
        fork2TokenIds[0] = forkTwoTokenId1;
        fork2TokenIds[1] = forkTwoTokenId2;

        assertEq(
            controller.balanceBatch(address(edition2), fork2TokenIds),
            edition2CreatorSplit * 2,
            "fork2 creator split total"
        );

        // withdraw batch from fork2
        vm.prank(users.user_1);
        uint256 withdrawalAmount = controller.withdrawBatch(address(edition2), fork2TokenIds);
        assertEq(withdrawalAmount, edition2CreatorSplit * 2, "fork2 creator split");

        uint256[] memory fork1TokenIds = new uint256[](2);
        fork1TokenIds[0] = forkOneTokenId1;
        fork1TokenIds[1] = forkOneTokenId2;

        // withdraw batch from fork1
        vm.prank(users.creator_1);
        uint256 withdrawalAmount2 = controller.withdrawBatch(address(edition1), fork1TokenIds);
        assertEq(withdrawalAmount2, edition1CreatorSplit * 2, "fork1 creator split");

        assertEq(controller.pending(address(edition), 1), rootSplit, "root split 1");
        assertEq(controller.pending(address(edition), rootTokenId2), rootSplit, "root split 2");

        // withdraw from root
        uint256[] memory rootTokenIds = new uint256[](2);
        rootTokenIds[0] = 1;
        rootTokenIds[1] = rootTokenId2;

        console.log("withdraw from root");
        vm.prank(users.creator_0);
        uint256 withdrawalAmount3 = controller.withdrawBatch(address(edition), rootTokenIds);
        assertEq(withdrawalAmount3, rootSplit * 2, "fork1 parent split");

        // verify balances
        assertEq(address(users.creator_0).balance, balance0 + rootSplit * 2, "creator 0 balance");
        assertEq(address(users.creator_1).balance, balance1 + edition1CreatorSplit * 2, "creator 1 balance");
        assertEq(address(users.user_1).balance, balanceUser1 + edition2CreatorSplit * 2, "user 1 balance");

        // verify user balances are zero
        assertEq(controller.balanceBatch(address(edition), rootTokenIds), 0);
        assertEq(controller.balanceBatch(address(edition1), fork1TokenIds), 0);
        assertEq(controller.balanceBatch(address(edition2), fork2TokenIds), 0);
    }

    function test__PlatformFee_RecordedOnMint() external {
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(controller) });
        emit PlatformFeeUpdated({ enabled: true });

        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        // mint
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");

        // check balance
        assertEq(controller.platformFeeBalance(), (TEST_TOKEN_PRICE * 1_000) / 10_000);
    }

    function test__DisablePlatformFee() external {
        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        // mint
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");

        // check balance
        assertEq(controller.platformFeeBalance(), (TEST_TOKEN_PRICE * 1_000) / 10_000);

        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(controller) });
        emit PlatformFeeUpdated({ enabled: false });

        // disable
        vm.prank(users.deployer);
        controller.enablePlatformFee(false);
    }

    function test__WithdrawPlatformFee() external {
        // cache deployer starting balance
        uint256 startingBalance = address(users.deployer).balance;

        vm.prank(users.deployer);
        controller.enablePlatformFee(true);

        // mint
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");

        // expected admin fee
        uint256 expectedPlatformFee = (TEST_TOKEN_PRICE * 1_000) / 10_000;

        // check balance
        assertEq(controller.platformFeeBalance(), expectedPlatformFee);

        // withdraw
        vm.prank(users.deployer);
        controller.withdrawPlatformFee(users.deployer);

        // check balance
        assertEq(controller.platformFeeBalance(), 0);

        // check deployer balance
        assertEq(address(users.deployer).balance, startingBalance + expectedPlatformFee);
    }

    function test__SetController_NewFundsRecipient() external {
        vm.startPrank(users.creator_0);
        uint256 tokenId = edition.add(
            TEST_TOKEN_URI,
            users.creator_0,
            TEST_TOKEN_MAX_SUPPLY,
            users.creator_0,
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter),
            optionalMintParams
        );

        edition.updateControllerData(tokenId, users.creator_1, TEST_PROFIT_SHARE);

        // check controller data
        assertEq(controller.fundsRecipient(address(edition), tokenId), users.creator_1);
    }
}
