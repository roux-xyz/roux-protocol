// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { IRouxAdministrator } from "src/interfaces/IRouxAdministrator.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract AdministratorTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    function test_RevertsWhen_Root_MaxDepthExceeded() external {
        // create forks up to max depth
        RouxEdition[] memory editions = _createForks(MAX_FORK_DEPTH);

        // modify default administrator data
        IRouxAdministrator.AdministratorData memory a = defaultAdministratorData;
        a.parentEdition = address(editions[MAX_FORK_DEPTH]);
        a.parentTokenId = 1;

        // attempt to add another fork
        vm.prank(users.creator_0);
        vm.expectRevert(IRouxAdministrator.MaxDepthExceeded.selector);
        edition.add(defaultTokenSaleData, a, TEST_TOKEN_URI, users.creator_0);
    }

    function test__RevertsWhen_SetAdministration_FundsRecipientIsZero() external {
        // modify default administrator data
        defaultAdministratorData.fundsRecipient = address(0);

        vm.prank(users.creator_0);
        vm.expectRevert(IRouxAdministrator.InvalidFundsRecipient.selector);
        edition.add(defaultTokenSaleData, defaultAdministratorData, TEST_TOKEN_URI, users.creator_0);
    }

    function test__RevertsWhen_EnableMintFor_OnlyOwner() external {
        // attempt to enable minting
        vm.prank(users.creator_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        administrator.adminFeeEnabled(true);
    }

    function test__RevertsWhen_UpgradeToAndCall_OnlyOwner() external {
        // attempt to upgrade to and call
        vm.prank(users.creator_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        administrator.upgradeToAndCall(address(edition), "");
    }

    function test__AddToken() external {
        // create edition instance
        vm.startPrank(users.creator_1);
        RouxEdition edition1 = RouxEdition(factory.create(""));

        // expect the relevant event to be emitted
        vm.expectEmit({ emitter: address(edition1) });
        emit TokenAdded({ id: 1, parentEdition: address(0), parentTokenId: 0 });

        edition1.add(defaultTokenSaleData, defaultAdministratorData, TEST_TOKEN_URI, users.creator_1);
        vm.stopPrank();

        // check token data
        assertEq(edition1.currentToken(), 1);

        // get attribution
        (address parentEdition, uint256 parentTokenId) = edition1.attribution(1);

        // verify attribution
        assertEq(parentEdition, address(0));
        assertEq(parentTokenId, 0);
    }

    function test__MintToken() external {
        // expect transfer to be emitted
        vm.expectEmit({ emitter: address(edition) });
        emit TransferSingle({ operator: users.user_0, from: address(0), to: users.user_0, id: 1, amount: 1 });

        // expect disbursement to be emitted
        vm.expectEmit({ emitter: address(administrator) });
        emit Disbursement({ edition: address(edition), tokenId: 1, amount: TEST_TOKEN_PRICE });

        // mint
        vm.prank(users.user_0);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        // check balance
        assertEq(administrator.balance(address(edition), 1), TEST_TOKEN_PRICE);
    }

    function test__AddToken_WithAttribution() external {
        /* create forked token with attribution */
        defaultAdministratorData.parentEdition = address(edition);
        defaultAdministratorData.parentTokenId = 1;
        defaultAdministratorData.fundsRecipient = address(users.creator_1);

        // create edition instance
        vm.startPrank(users.creator_1);
        RouxEdition edition1 = RouxEdition(factory.create(""));

        // expect the relevant event to be emitted
        vm.expectEmit({ emitter: address(edition1) });
        emit TokenAdded({ id: 1, parentEdition: address(edition), parentTokenId: 1 });

        edition1.add(defaultTokenSaleData, defaultAdministratorData, TEST_TOKEN_URI, users.creator_1);
        vm.stopPrank();

        // check token data
        assertEq(edition1.currentToken(), 1);

        // get attribution
        (address parentEdition, uint256 parentTokenId) = edition1.attribution(1);

        // verify attribution
        assertEq(parentEdition, address(edition));
        assertEq(parentTokenId, 1);
    }

    function test__Mint_WithAttribution_DepthOf1() external {
        // modifiy default administrator data
        defaultAdministratorData.parentEdition = address(edition);
        defaultAdministratorData.parentTokenId = 1;
        defaultAdministratorData.fundsRecipient = address(users.creator_1);

        // create edition instance
        vm.startPrank(users.creator_1);
        RouxEdition edition1 = RouxEdition(factory.create(""));

        /* create forked token with attribution */
        edition1.add(defaultTokenSaleData, defaultAdministratorData, TEST_TOKEN_URI, users.creator_1);
        vm.stopPrank();

        // compute split
        uint256 profitShare = administrator.profitShare(address(edition), 1);
        uint256 parentShare = (TEST_TOKEN_PRICE * (10_000 - profitShare)) / 10_000;
        uint256 childShare = TEST_TOKEN_PRICE - parentShare;

        // expect transfer to be emitted
        vm.expectEmit({ emitter: address(edition1) });
        emit TransferSingle({ operator: users.user_0, from: address(0), to: users.user_0, id: 1, amount: 1 });

        // expect disbursement to be emitted
        vm.expectEmit({ emitter: address(administrator) });
        emit Disbursement({ edition: address(edition1), tokenId: 1, amount: childShare });

        // expect pending to be emitted
        vm.expectEmit({ emitter: address(administrator) });
        emit PendingUpdated({
            edition: address(edition1),
            tokenId: 1,
            parent: address(edition),
            parentTokenId: 1,
            amount: parentShare
        });

        // mint
        vm.prank(users.user_0);
        edition1.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        // check balance
        assertEq(administrator.balance(address(edition1), 1), childShare);
        assertEq(administrator.pending(address(edition), 1), parentShare);
    }

    function test__Withdraw() external {
        // cache starting balance
        uint256 creator0StartingBalance = address(users.creator_0).balance;

        // mint
        vm.prank(users.user_0);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        // check balance
        assertEq(administrator.balance(address(edition), 1), TEST_TOKEN_PRICE);

        // expect withdrawal to be emitted
        vm.expectEmit({ emitter: address(administrator) });
        emit Withdrawn({ edition: address(edition), tokenId: 1, to: users.creator_0, amount: TEST_TOKEN_PRICE });

        // withdraw
        administrator.withdraw(address(edition), 1);

        // check balance
        assertEq(address(users.creator_0).balance, creator0StartingBalance + TEST_TOKEN_PRICE);
    }

    function test__Withdraw_WithAttribution_DepthOf1() external {
        // cache starting balances
        uint256 creator0StartingBalance = address(users.creator_0).balance;
        uint256 creator1StartingBalance = address(users.creator_1).balance;

        // modifiy default administrator data
        defaultAdministratorData.parentEdition = address(edition);
        defaultAdministratorData.parentTokenId = 1;
        defaultAdministratorData.fundsRecipient = address(users.creator_1);

        // create edition instance
        vm.startPrank(users.creator_1);
        RouxEdition edition1 = RouxEdition(factory.create(""));

        /* create forked token with attribution */
        edition1.add(defaultTokenSaleData, defaultAdministratorData, TEST_TOKEN_URI, users.creator_1);
        vm.stopPrank();

        // compute split
        uint256 profitShare = administrator.profitShare(address(edition), 1);
        uint256 parentShare = (TEST_TOKEN_PRICE * (10_000 - profitShare)) / 10_000;
        uint256 childShare = TEST_TOKEN_PRICE - parentShare;

        // mint
        vm.prank(users.user_0);
        edition1.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        // check balance
        assertEq(administrator.balance(address(edition1), 1), childShare);
        assertEq(administrator.pending(address(edition), 1), parentShare);

        // expect withdrawal to be emitted
        vm.expectEmit({ emitter: address(administrator) });
        emit Withdrawn({ edition: address(edition1), tokenId: 1, to: users.creator_1, amount: childShare });

        // withdraw
        administrator.withdraw(address(edition1), 1);

        // check balances
        assertEq(address(users.creator_1).balance, creator1StartingBalance + childShare);

        // expect withdrawal to be emitted
        vm.expectEmit({ emitter: address(administrator) });
        emit Withdrawn({ edition: address(edition), tokenId: 1, to: users.creator_0, amount: parentShare });

        // withdraw
        administrator.withdraw(address(edition), 1);

        // check balances
        assertEq(address(users.creator_0).balance, creator0StartingBalance + parentShare);
    }

    function test__WithdrawBatch() external {
        // cache starting balances
        uint256 creator0StartingBalance = address(users.creator_0).balance;

        // add token
        vm.prank(users.creator_0);
        edition.add(defaultTokenSaleData, defaultAdministratorData, TEST_TOKEN_URI, users.creator_0);

        // mint
        vm.prank(users.user_0);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        // mint 2nd token
        vm.prank(users.user_0);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 2, 1);

        // check balance
        assertEq(administrator.balance(address(edition), 1), TEST_TOKEN_PRICE);
        assertEq(administrator.balance(address(edition), 2), TEST_TOKEN_PRICE);

        // expect withdrawal to be emitted
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        vm.expectEmit({ emitter: address(administrator) });
        emit WithdrawnBatch({
            edition: address(edition),
            tokenIds: tokenIds,
            to: users.creator_0,
            amount: TEST_TOKEN_PRICE * 2
        });

        // withdraw
        administrator.withdrawBatch(address(edition), tokenIds);

        // check balances
        assertEq(address(users.creator_0).balance, creator0StartingBalance + TEST_TOKEN_PRICE * 2);
    }

    function test__WithdrawBatch_WithAttribution_DepthOf1() external {
        // cache starting balances
        uint256 creator1StartingBalance = address(users.creator_1).balance;

        // modifiy default administrator data
        defaultAdministratorData.parentEdition = address(edition);
        defaultAdministratorData.parentTokenId = 1;
        defaultAdministratorData.fundsRecipient = address(users.creator_1);

        // create edition instance
        vm.prank(users.creator_1);
        RouxEdition edition1 = RouxEdition(factory.create(""));

        /* create forked token with attribution */
        vm.prank(users.creator_1);
        edition1.add(defaultTokenSaleData, defaultAdministratorData, TEST_TOKEN_URI, users.creator_1);

        // compute split
        uint256 profitShare = administrator.profitShare(address(edition), 1);
        uint256 parentShare = (TEST_TOKEN_PRICE * (10_000 - profitShare)) / 10_000;
        uint256 childShare = TEST_TOKEN_PRICE - parentShare;

        // mint
        vm.prank(users.user_0);
        edition1.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        // check balance
        assertEq(administrator.balance(address(edition1), 1), childShare);
        assertEq(administrator.pending(address(edition), 1), parentShare);

        // revert default administrator data
        defaultAdministratorData.parentEdition = address(0);
        defaultAdministratorData.parentTokenId = 0;

        // create a 2nd token
        vm.prank(users.creator_1);
        edition1.add(defaultTokenSaleData, defaultAdministratorData, TEST_TOKEN_URI, users.creator_1);

        // mint 2nd token
        vm.prank(users.user_0);
        edition1.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 2, 1);

        // expect withdrawal to be emitted
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        vm.expectEmit({ emitter: address(administrator) });
        emit WithdrawnBatch({
            edition: address(edition1),
            tokenIds: tokenIds,
            to: users.creator_1,
            amount: childShare + TEST_TOKEN_PRICE
        });

        // withdraw
        administrator.withdrawBatch(address(edition1), tokenIds);

        // check balances
        assertEq(address(users.creator_1).balance, creator1StartingBalance + childShare + TEST_TOKEN_PRICE);
    }

    function test__Root_Depth1() external {
        // modify default administrator data
        defaultAdministratorData.parentEdition = address(edition);
        defaultAdministratorData.parentTokenId = 1;

        // create edition instance
        vm.startPrank(users.creator_1);
        RouxEdition edition1 = RouxEdition(factory.create(""));

        /* create forked token with attribution */
        edition1.add(defaultTokenSaleData, defaultAdministratorData, TEST_TOKEN_URI, users.creator_1);
        vm.stopPrank();

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = administrator.root(address(edition1), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, 1);
    }

    function test__Root_Depth2() external {
        RouxEdition[] memory editions = _createForks(2);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = administrator.root(address(editions[2]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, 2);
    }

    function test__Root_Depth_MaxDepth() external {
        RouxEdition[] memory editions = _createForks(MAX_FORK_DEPTH);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = administrator.root(address(editions[MAX_FORK_DEPTH]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, MAX_FORK_DEPTH);
    }

    function test__Root_DepthOfN(uint256 num) external {
        uint256 n = bound(num, 1, MAX_FORK_DEPTH);
        RouxEdition[] memory editions = _createForks(n);

        /* get root */
        (address root, uint256 tokenId, uint256 depth) = administrator.root(address(editions[n]), 1);

        assertEq(root, address(edition));
        assertEq(tokenId, 1);
        assertEq(depth, n);

        /* sanity checks */
        assertEq(editions.length, n + 1); // original + n forks
        for (uint256 i = 0; i < n + 1; i++) {
            assertEq(factory.isEdition(address(editions[i])), true);
        }
    }

    function test__Owner() external {
        assertEq(administrator.owner(), address(users.deployer));
    }

    function test__AdminFee() external {
        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(administrator) });
        emit AdminFeeUpdated({ enabled: true });

        vm.prank(users.deployer);
        administrator.adminFeeEnabled(true);

        // mint
        vm.prank(users.user_0);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        // check balance
        assertEq(administrator.adminFeeBalance(), (TEST_TOKEN_PRICE * 1_000) / 10_000);
    }

    function test__DisableAdminFee() external {
        vm.prank(users.deployer);
        administrator.adminFeeEnabled(true);

        // mint
        vm.prank(users.user_0);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        // check balance
        assertEq(administrator.adminFeeBalance(), (TEST_TOKEN_PRICE * 1_000) / 10_000);

        // Expect the relevant event to be emitted.
        vm.expectEmit({ emitter: address(administrator) });
        emit AdminFeeUpdated({ enabled: false });

        // disable
        vm.prank(users.deployer);
        administrator.adminFeeEnabled(false);
    }

    function test__WithdrawAdminFee() external {
        // cache deployer starting balance
        uint256 startingBalance = address(users.deployer).balance;

        vm.prank(users.deployer);
        administrator.adminFeeEnabled(true);

        // mint
        vm.prank(users.user_0);
        edition.mint{ value: TEST_TOKEN_PRICE }(users.user_0, 1, 1);

        // expected admin fee
        uint256 expectedAdminFee = (TEST_TOKEN_PRICE * 1_000) / 10_000;

        // check balance
        assertEq(administrator.adminFeeBalance(), expectedAdminFee);

        // withdraw
        vm.prank(users.deployer);
        administrator.withdrawAdminFee(users.deployer);

        // check balance
        assertEq(administrator.adminFeeBalance(), 0);

        // check deployer balance
        assertEq(address(users.deployer).balance, startingBalance + expectedAdminFee);
    }
}
