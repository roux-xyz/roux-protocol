// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { Controller } from "src/Controller.sol";
import { IController } from "src/interfaces/IController.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";

import { RouxEdition } from "src/RouxEdition.sol";
import { EditionMinter } from "src/minters/EditionMinter.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract EditionTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    function test__RevertWhen_InvalidTokenId_0() external {
        vm.expectRevert();
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 0, 1, "");
    }

    function test__RevertWhen_InvalidTokenId_2() external {
        vm.expectRevert();
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 2, 1, "");
    }

    function test__RevertWhen_OnlyOwner_AddToken() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
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
    }

    function test__RevertWhen_OnlyOwner_UpdateUri() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        RouxEdition(address(edition)).updateUri(1, "https://new.com");
    }

    function test__RevertWhen_OnlyOwner_AddMinter() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        RouxEdition(address(edition)).addMinter(1, users.user_0);
    }

    function test__RevertWhen_OnlyOwner_UpdateMintParams() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        RouxEdition(address(edition)).updateMintParams(1, users.user_0, "");
    }

    function test__RevertWhen_InvalidCaller() external {
        vm.prank(users.user_1);
        vm.expectRevert(IRouxEdition.InvalidCaller.selector);
        edition.mint(users.user_0, 1, 1, "");
    }

    function test__RevertWhen_MaxSupplyExceeded() external {
        vm.prank(users.creator_0);
        uint256 tokenId = edition.add(
            TEST_TOKEN_URI,
            users.creator_0,
            1,
            users.creator_0,
            TEST_PROFIT_SHARE,
            address(0),
            0,
            address(editionMinter),
            optionalMintParams
        );

        vm.prank(users.user_1);
        vm.expectRevert(IRouxEdition.MaxSupplyExceeded.selector);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), tokenId, 1, "");
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    function test__Owner() external {
        assertEq(edition.owner(), users.creator_0);
    }

    function test__Creator() external {
        assertEq(edition.creator(1), users.creator_0);
    }

    function test__CurrentToken() external {
        assertEq(edition.currentToken(), 1);
    }

    function test__CurrentToken_AfterAddToken() external {
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

        assertEq(edition.currentToken(), 2);
    }

    function test__TotalSupply() external {
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");

        // creator minted token on add
        assertEq(edition.totalSupply(1), 2);
    }

    function test__Uri() external {
        assertEq(edition.uri(1), TEST_TOKEN_URI);
    }

    function test__ContractUri() external {
        assertEq(edition.contractURI(), TEST_CONTRACT_URI);
    }

    function test__Attribution() external {
        vm.startPrank(users.creator_1);

        // create edition instance
        bytes memory params = abi.encode(TEST_CONTRACT_URI, "");
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

        (address attribution, uint256 parentId) = edition1.attribution(1);

        assertEq(attribution, address(edition));
        assertEq(parentId, 1);
    }

    function test__Exists() external {
        assert(edition.exists(1));
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    function test__TransferOwnership() external {
        vm.prank(users.creator_0);
        edition.transferOwnership(users.creator_1);
        assertEq(edition.owner(), users.creator_1);
    }

    function test__Mint() external {
        // expect transfer to be emitted
        vm.expectEmit({ emitter: address(edition) });
        emit TransferSingle({ operator: address(editionMinter), from: address(0), to: users.user_0, id: 1, amount: 1 });

        // mint
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");

        // check balance
        assertEq(edition.balanceOf(users.user_0, 1), 1);

        // check total supply
        assertEq(edition.totalSupply(1), 2);
    }

    function test__AddToken() external {
        // expect transfer to be emitted for token minted to creator
        vm.expectEmit({ emitter: address(edition) });
        emit TransferSingle({
            operator: address(users.creator_0),
            from: address(0),
            to: users.creator_0,
            id: 2,
            amount: 1
        });

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

        // verify token minted to creator
        assertEq(edition.balanceOf(users.creator_0, 2), 1);
        assertEq(edition.totalSupply(2), 1);

        // verify that token can be minted
        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");
        assertEq(edition.balanceOf(users.user_0, 1), 1);
        assertEq(edition.totalSupply(1), 2);
    }

    function test__AddToken_WithAttribution() external {
        vm.startPrank(users.creator_1);

        // create edition instance
        bytes memory params = abi.encode(TEST_CONTRACT_URI, "");
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

        (address attribution, uint256 parentId) = edition1.attribution(1);

        assertEq(attribution, address(edition));
        assertEq(parentId, 1);

        vm.prank(users.user_0);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");
        assertEq(edition.balanceOf(users.user_0, 1), 1);
    }

    function test__AddToken_WithAttribution_DepthOf3() external {
        vm.startPrank(users.creator_1);

        // create new edition instance
        bytes memory params = abi.encode(TEST_CONTRACT_URI, "");
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

        (address attribution, uint256 parentId) = edition1.attribution(tokenId);

        assertEq(attribution, address(edition));
        assertEq(parentId, 1);

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

        // verify attribution
        (address attribution2, uint256 parentId2) = edition.attribution(tokenId2);
        assertEq(attribution2, address(edition1));
        assertEq(parentId2, 1);
    }

    function test__UpdateUri() external {
        vm.prank(users.creator_0);
        RouxEdition(address(edition)).updateUri(1, "https://new.com");
        assertEq(edition.uri(1), "https://new.com");
    }

    function test__AddMinter() external {
        vm.prank(users.creator_0);
        RouxEdition(address(edition)).addMinter(1, address(defaultMinter));
        assert(edition.isMinter(1, address(defaultMinter)));
    }

    function test__RemoveMinter() external {
        vm.prank(users.creator_0);
        RouxEdition(address(edition)).removeMinter(1, address(editionMinter));
        assert(!edition.isMinter(1, address(editionMinter)));

        // verify that token cannot be minted
        vm.prank(users.user_0);
        vm.expectRevert(IRouxEdition.InvalidCaller.selector);
        editionMinter.mint{ value: TEST_TOKEN_PRICE }(users.user_0, address(edition), 1, 1, "");
    }

    function test__UpdateMintParams() external {
        uint128 newPrice = 0.088 ether;
        uint40 newMintStart = uint40(block.timestamp + 7 days);
        uint40 newMintEnd = uint40(block.timestamp + 14 days);
        uint16 newMaxMintable = 2;

        bytes memory params = _encodeMintParams(newPrice, newMintStart, newMintEnd, newMaxMintable);

        vm.prank(users.creator_0);
        RouxEdition(address(edition)).updateMintParams(1, address(editionMinter), params);

        assertEq(editionMinter.price(address(edition), 1), newPrice);
    }
}
