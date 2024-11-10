// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";

import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";

import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract Add_RouxEdition_Unit_Concrete_Test is BaseTest {
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

    /// @dev only edition owner can add token
    function test__RevertWhen_OnlyOwner_AddToken() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.add(addParams);
    }

    /// @dev only edition owner can set extension
    function test__RevertWhen_OnlyOwner_SetExtension() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.setExtension(1, address(mockExtension), true, "");
    }

    /// @dev cannot add token with zero max supply
    function test__RevertWhen_AddToken_MaxSupplyIsZero() external {
        // modify default add params
        addParams.maxSupply = 0;

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidParams.selector);
        edition.add(addParams);
    }

    /// @dev invalid extension reverts - unsupported interface
    function test__RevertWhen_AddToken_InvalidExtension_UnsupportedInterface() external {
        // create edition instance
        IRouxEdition edition_ = _createEdition(users.creator_1);

        // modify default add params
        addParams.extension = address(edition_);

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidExtension.selector);
        edition.add(addParams);
    }

    /* -------------------------------------------- */
    /* writes                                       */
    /* -------------------------------------------- */

    /// @dev max supply is max uint128
    function test__AddToken_MaxSupplyIsMaxUint128() external {
        addParams.maxSupply = type(uint128).max;

        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        assertEq(edition.maxSupply(tokenId_), type(uint128).max);
    }

    /// @dev token id is incremented after add
    function test__AddToken_TokenIdIsIncremented() external {
        // cache starting token id
        uint256 currentTokenId = edition.currentToken();

        // add token
        vm.prank(creator);
        edition.add(addParams);

        // token id is incremented
        assertEq(edition.currentToken(), currentTokenId + 1);
    }

    /// @dev default price is set after add
    function test__AddToken_DefaultPriceIsSet() external {
        // add token
        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        // default price is set
        assertEq(edition.defaultPrice(tokenId_), addParams.defaultPrice);
    }

    /// @dev default mint params are set after add
    function test__AddToken_DefaultMintParamsAreSet() external {
        // add token
        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        assertEq(edition.defaultMintParams(tokenId_).defaultPrice, addParams.defaultPrice);
        assertEq(edition.defaultMintParams(tokenId_).gate, false);
    }

    /// @dev gate is set after add - false default
    function test__AddToken_GateIsSet_FalseDefault() external {
        // add token
        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        assertEq(edition.isGated(tokenId_), false);
    }

    /// @dev gate is set after add - false
    function test__AddToken_GateIsSet_True() external {
        addParams.gate = true;

        // add token
        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        assertEq(edition.isGated(tokenId_), true);
    }

    /// @dev token uri is set after add
    function test__AddToken_UriIsSet() external {
        bytes32 hashDigest = 0xC3C4733EC8AFFD06CF9E9FF50FFC6BCD2EC85A6170004BB709669C31DE94391A;

        string memory newUri = "ipfs://bafkreigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";

        // modify default add params
        addParams.ipfsHash = hashDigest;

        // add token
        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        assertEq(edition.uri(tokenId_), newUri);
    }

    /// @dev token creator is set after add
    function test__AddToken_CreatorIsSet() external {
        // create edition instance
        IRouxEdition edition_ = _createEdition(users.creator_1);

        // add token
        vm.prank(users.creator_1);
        uint256 tokenId_ = edition_.add(addParams);

        assertEq(edition_.creator(tokenId_), users.creator_1);
    }

    /// @dev extension is set on add
    function test__AddToken_ExtensionIsSet() external {
        addParams.extension = address(mockExtension);

        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        assertTrue(edition.isRegisteredExtension(tokenId_, address(mockExtension)));
    }

    /// @dev token max supply is set after add
    function test__AddToken_MaxSupplyIsSet() external {
        uint128 maxSupply = 888;

        // modify default add params
        addParams.maxSupply = maxSupply;

        // add token
        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        assertEq(edition.maxSupply(tokenId_), maxSupply);
    }

    /// @dev token is minted to creator after add
    function test__AddToken_TokenIsMintedToCreator() external {
        // add token
        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        assertEq(edition.balanceOf(creator, tokenId_), 1);
        assertEq(edition.totalSupply(tokenId_), 1);
    }

    /// @dev event is emitted when token is added
    function test__AddToken_EventIsEmitted() external {
        // get new edition instance
        IRouxEdition edition_ = _createEdition(users.creator_1);

        // expect emit
        vm.expectEmit({ emitter: address(edition_) });
        emit EventsLib.TokenAdded(1);

        // add token
        vm.prank(users.creator_1);
        edition_.add(addParams);
    }
}
