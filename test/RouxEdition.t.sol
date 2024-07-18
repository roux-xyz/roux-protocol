// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { Controller } from "src/Controller.sol";
import { IController } from "src/interfaces/IController.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";

import { RouxEdition } from "src/RouxEdition.sol";
import { BaseTest } from "./Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

import { EditionData } from "src/types/DataTypes.sol";

contract EditionTest is BaseTest {
    function setUp() public virtual override {
        BaseTest.setUp();

        // approve token
        vm.prank(users.user_0);
        mockUSDC.approve(address(edition), type(uint256).max);

        // approve token - user_1
        vm.prank(users.user_1);
        mockUSDC.approve(address(edition), type(uint256).max);
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    function test__RevertWhen_InvalidTokenId_0() external {
        vm.expectRevert();
        edition.mint(users.user_0, 0, 1, address(0), address(0), "");
    }

    function test__RevertWhen_InvalidTokenId_2() external {
        vm.expectRevert();
        edition.mint(users.user_0, 2, 1, address(0), address(0), "");
    }

    function test__RevertWhen_OnlyOwner_AddToken() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        edition.add(defaultAddParams);
    }

    function test__RevertWhen_AddToken_MaxSupplyIsZero() external {
        // get default add params
        EditionData.AddParams memory modifiedAddParams = defaultAddParams;

        // modify default add params
        modifiedAddParams.maxSupply = 0;

        vm.expectRevert(IRouxEdition.InvalidParams.selector);
        vm.prank(users.creator_0);
        edition.add(modifiedAddParams);
    }

    function test__RevertWhen_AddToken_CreatorIsZeroAddress() external {
        //  get default add params
        EditionData.AddParams memory modifiedAddParams = defaultAddParams;

        // modify default add params
        modifiedAddParams.creator = address(0);

        vm.expectRevert(IRouxEdition.InvalidParams.selector);
        vm.prank(users.creator_0);
        edition.add(modifiedAddParams);
    }

    function test__RevertWhen_OnlyOwner_UpdateUri() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        edition.updateUri(1, "https://new.com");
    }

    function test__RevertWhen_OnlyOwner_AddExtension() external {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        edition.setExtension(1, address(edition), true, "");
    }

    function test__RevertWhen_OnlyOwner_SetCollection() external {
        // create token id array
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        // get encoded batch id
        uint256 batchId = uint256(keccak256(abi.encode(tokenIds)));

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(users.user_0);
        edition.setCollection(tokenIds, address(singleEditionCollection), true);
    }

    function test__RevertWhen_MaxSupplyExceeded() external {
        // copy default add params
        EditionData.AddParams memory modifiedAddParams = defaultAddParams;

        // modify default add params
        modifiedAddParams.maxSupply = 1;

        vm.prank(users.creator_0);
        uint256 tokenId = edition.add(modifiedAddParams);

        vm.prank(users.user_1);
        vm.expectRevert(IRouxEdition.MaxSupplyExceeded.selector);
        edition.mint(users.user_0, tokenId, 1, address(0), address(0), "");
    }

    function test__RevertWhen_AddInvalidExtension_ZeroAddress() external {
        vm.prank(users.creator_0);
        vm.expectRevert(IRouxEdition.InvalidExtension.selector);
        edition.setExtension(1, address(0), true, "");
    }

    function test__RevertWhen_AddInvalidExtension_UnsupportedInteface() external {
        vm.prank(users.creator_0);
        vm.expectRevert(IRouxEdition.InvalidExtension.selector);
        edition.setExtension(1, address(edition), true, "");
    }

    function test__RevertWhen_AlreadyInitialized() external {
        // encode params
        bytes memory initData = abi.encodeWithSelector(edition.initialize.selector, "https://new-contract-uri.com");

        // assert current implementation
        vm.prank(users.user_0);
        vm.expectRevert("Already initialized");
        edition.initialize(initData);
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
        edition.add(defaultAddParams);

        assertEq(edition.currentToken(), 2);
    }

    function test__TotalSupply() external {
        vm.prank(users.user_0);
        edition.mint(users.user_0, 1, 1, address(0), address(0), "");

        // creator minted token on add
        assertEq(edition.totalSupply(1), 2);
    }

    function test__Uri() external {
        assertEq(edition.uri(1), TOKEN_URI);
    }

    function test__ContractUri() external {
        assertEq(edition.contractURI(), CONTRACT_URI);
    }

    function test__Exists() external {
        assertEq(edition.exists(1), true);
    }

    function test__Implementation() external {
        assertEq(edition.IMPLEMENTATION_VERSION(), "0.1");
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
        emit TransferSingle({ operator: users.user_0, from: address(0), to: users.user_0, id: 1, amount: 1 });

        // mint
        vm.prank(users.user_0);
        edition.mint(users.user_0, 1, 1, address(0), address(0), "");

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
        edition.add(defaultAddParams);

        // verify token minted to creator
        assertEq(edition.balanceOf(users.creator_0, 2), 1);
        assertEq(edition.totalSupply(2), 1);

        // verify that token can be minted
        vm.prank(users.user_0);
        edition.mint(users.user_0, 1, 1, address(0), address(0), "");
        assertEq(edition.balanceOf(users.user_0, 1), 1);
        assertEq(edition.totalSupply(1), 2);
    }

    function test__AddToken_WithAttribution() external {
        (RouxEdition forkEdition, uint256 tokenId) = _createFork(edition, 1, users.creator_1);

        (address parentToken, uint256 parentTokenId) = registry.attribution(address(forkEdition), tokenId);

        assertEq(parentToken, address(edition));
        assertEq(parentTokenId, 1);

        vm.startPrank(users.user_0);

        mockUSDC.approve(address(forkEdition), type(uint256).max);
        forkEdition.mint(users.user_0, 1, 1, address(0), address(0), "");
        assertEq(forkEdition.balanceOf(users.user_0, 1), 1);

        vm.stopPrank();
    }

    function test__AddToken_WithAttribution_DepthOf2() external {
        RouxEdition[] memory editions = _createForks(2);

        // verify attribution of 2nd fork
        (address parentToken, uint256 parentTokenId) = registry.attribution(address(editions[2]), 1);
        assertEq(parentToken, address(editions[1]));
        assertEq(parentTokenId, 1);

        // verify attribution of 1st fork
        (parentToken, parentTokenId) = registry.attribution(address(editions[1]), 1);
        assertEq(parentToken, address(editions[0]));
        assertEq(parentTokenId, 1);
    }

    function test__UpdateUri() external {
        vm.prank(users.creator_0);
        edition.updateUri(1, "https://new.com");
        assertEq(edition.uri(1), "https://new.com");
    }
}
