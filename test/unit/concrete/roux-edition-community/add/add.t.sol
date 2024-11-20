// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";

import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

import { RouxCommunityEdition } from "src/core/RouxCommunityEdition.sol";

contract Add_RouxCommunityEdition_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    EditionData.AddParams addParams;

    function setUp() public override {
        BaseTest.setUp();

        // copy default add params
        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when allowlist enabled and caller is not allowlisted
    function test__RevertWhen_AddToken_AllowlistEnabled_CallerNotAllowlisted() external {
        // enable allowlist
        vm.prank(creator);
        RouxCommunityEdition(address(communityEdition)).enableAllowlist(true);

        // attempt to add token
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxCommunityEdition_NotAllowed.selector);
        communityEdition.add(addParams);

        // attempt to add token - creator is not allowlisted
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxCommunityEdition_NotAllowed.selector);
        communityEdition.add(addParams);
    }

    /* -------------------------------------------- */
    /* writes                                       */
    /* -------------------------------------------- */

    /// @dev max supply is max uint128
    function test__AddToken_MaxSupplyIsMaxUint128() external {
        addParams.maxSupply = type(uint128).max;

        vm.prank(users.creator_2);
        uint256 tokenId_ = communityEdition.add(addParams);

        assertEq(communityEdition.maxSupply(tokenId_), type(uint128).max);
    }

    /// @dev token id is incremented after add
    function test__AddToken_TokenIdIsIncremented() external {
        // cache starting token id
        uint256 currentTokenId = communityEdition.currentToken();

        // add token
        vm.prank(users.creator_2);
        communityEdition.add(addParams);

        // token id is incremented
        assertEq(communityEdition.currentToken(), currentTokenId + 1);
    }

    /// @dev default price is set after add
    function test__AddToken_DefaultPriceIsSet() external {
        // add token
        vm.prank(users.creator_2);
        uint256 tokenId_ = communityEdition.add(addParams);

        // default price is set
        assertEq(communityEdition.defaultPrice(tokenId_), addParams.defaultPrice);
    }

    /// @dev default mint params are set after add
    function test__AddToken_DefaultMintParamsAreSet() external {
        // add token
        vm.prank(users.creator_2);
        uint256 tokenId_ = communityEdition.add(addParams);

        assertEq(communityEdition.defaultMintParams(tokenId_).defaultPrice, addParams.defaultPrice);
        assertEq(communityEdition.defaultMintParams(tokenId_).gate, false);
    }

    /// @dev gate is set after add - false default
    function test__AddToken_GateIsSet_FalseDefault() external {
        // add token
        vm.prank(users.creator_2);
        uint256 tokenId_ = communityEdition.add(addParams);

        assertEq(communityEdition.isGated(tokenId_), false);
    }

    /// @dev gate is set after add - false
    function test__AddToken_GateIsSet_True() external {
        addParams.gate = true;

        // add token
        vm.prank(users.creator_2);
        uint256 tokenId_ = communityEdition.add(addParams);

        assertEq(communityEdition.isGated(tokenId_), true);
    }

    /// @dev token uri is set after add
    function test__AddToken_UriIsSet() external {
        bytes32 hashDigest = 0xC3C4733EC8AFFD06CF9E9FF50FFC6BCD2EC85A6170004BB709669C31DE94391A;

        string memory newUri = "ipfs://bafkreigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";

        // modify default add params
        addParams.ipfsHash = hashDigest;

        // add token
        vm.prank(users.creator_2);
        uint256 tokenId_ = communityEdition.add(addParams);

        assertEq(communityEdition.uri(tokenId_), newUri);
    }

    /// @dev token creator is set after add
    function test__AddToken_CreatorIsSet() external {
        // create edition instance
        IRouxEdition communityEdition_ = _createCommunityEdition(creator);

        // add token
        vm.prank(users.creator_2);
        uint256 tokenId_ = communityEdition_.add(addParams);

        assertEq(communityEdition_.creator(tokenId_), users.creator_2);
    }

    /// @dev extension is set on add
    function test__AddToken_ExtensionIsSet() external {
        addParams.extension = address(mockExtension);

        vm.prank(users.creator_2);
        uint256 tokenId_ = communityEdition.add(addParams);

        assertTrue(communityEdition.isRegisteredExtension(tokenId_, address(mockExtension)));
    }

    /// @dev token max supply is set after add
    function test__AddToken_MaxSupplyIsSet() external {
        uint128 maxSupply = 888;

        // modify default add params
        addParams.maxSupply = maxSupply;

        // add token
        vm.prank(users.creator_2);
        uint256 tokenId_ = communityEdition.add(addParams);

        assertEq(communityEdition.maxSupply(tokenId_), maxSupply);
    }

    /// @dev token is minted to creator after add
    function test__AddToken_TokenIsMintedToCreator() external {
        // add token
        vm.prank(users.creator_2);
        uint256 tokenId_ = communityEdition.add(addParams);

        assertEq(communityEdition.balanceOf(users.creator_2, tokenId_), 1);
        assertEq(communityEdition.totalSupply(tokenId_), 1);
    }

    /// @dev event is emitted when token is added
    function test__AddToken_EventIsEmitted() external {
        // get new edition instance
        IRouxEdition communityEdition_ = _createCommunityEdition(users.creator_1);

        // expect emit
        vm.expectEmit({ emitter: address(communityEdition_) });
        emit EventsLib.TokenAdded(1);

        // add token
        vm.prank(users.creator_2);
        communityEdition_.add(addParams);
    }

    /// @dev token can be added after allowlist is enabled
    function test__AddToken_AllowlistEnabled() external {
        // enable allowlist
        vm.prank(creator);
        RouxCommunityEdition(address(communityEdition)).enableAllowlist(true);

        // add users to allowlist
        address[] memory addresses = new address[](2);
        addresses[0] = users.creator_2;
        addresses[1] = user;

        vm.prank(creator);
        RouxCommunityEdition(address(communityEdition)).addToAllowlist(addresses);

        // add token
        vm.prank(user);
        uint256 tokenIdUser_ = communityEdition.add(addParams);

        // add another token
        vm.prank(users.creator_2);
        uint256 tokenIdCreator_ = communityEdition.add(addParams);

        assertEq(communityEdition.currentToken(), 3);

        // token is minted to account that adds token
        assertEq(communityEdition.balanceOf(users.creator_2, tokenIdCreator_), 1);
        assertEq(communityEdition.balanceOf(user, tokenIdUser_), 1);
    }
}
