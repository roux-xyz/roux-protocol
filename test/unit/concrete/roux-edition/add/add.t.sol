// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";

import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";

contract Add_RouxEdition_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
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
        vm.prank(users.user_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.add(addParams);
    }

    /// @dev only edition owner can set extension
    function test__RevertWhen_OnlyOwner_SetExtension() external {
        vm.prank(users.user_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.setExtension(1, address(mockExtension), true, "");
    }

    /// @dev cannot add token with zero max supply
    function test__RevertWhen_AddToken_MaxSupplyIsZero() external {
        // modify default add params
        addParams.maxSupply = 0;

        vm.prank(users.creator_0);
        vm.expectRevert(IRouxEdition.InvalidParams.selector);
        edition.add(addParams);
    }

    /// @dev cannot add token with zero address as creator
    function test__RevertWhen_AddToken_CreatorIsZeroAddress() external {
        // modify default add params
        addParams.creator = address(0);

        vm.prank(users.creator_0);
        vm.expectRevert(IRouxEdition.InvalidParams.selector);
        edition.add(addParams);
    }

    /// @dev cannot set parent token address to self
    function test__RevertWhen_AddToken_ParentEditionIsSelf() external {
        // modify default add params
        addParams.parentEdition = address(edition);

        vm.prank(users.creator_0);
        vm.expectRevert(IRouxEdition.InvalidParams.selector);
        edition.add(addParams);
    }

    /// @dev cannot add token with valid parent token address and zero token id
    function test__RevertWhen_AddToken_InvalidParentTokenId() external {
        // create edition instance
        IRouxEdition edition_ = _createEdition(users.creator_1);

        // modify default add params
        addParams.parentEdition = address(edition);
        addParams.parentTokenId = 0;

        vm.prank(users.creator_1);
        vm.expectRevert(IRouxEdition.InvalidParams.selector);
        edition_.add(addParams);
    }

    /// @dev cannot add token with zero parent token address and valid token id
    function test__RevertWhen_AddToken_InvalidParentEdition() external {
        // create edition instance
        IRouxEdition edition_ = _createEdition(users.creator_1);

        // modify default add params
        addParams.parentEdition = address(0);
        addParams.parentTokenId = 1;

        vm.prank(users.creator_1);
        vm.expectRevert(IRouxEdition.InvalidParams.selector);
        edition_.add(addParams);
    }

    /// @dev invalid extension reverts - unsupported interface
    function test__RevertWhen_AddToken_InvalidExtension_UnsupportedInterface() external {
        // create edition instance
        IRouxEdition edition_ = _createEdition(users.creator_1);

        // modify default add params
        addParams.extension = address(edition_);

        vm.prank(users.creator_0);
        vm.expectRevert(IRouxEdition.InvalidExtension.selector);
        edition.add(addParams);
    }

    /* -------------------------------------------- */
    /* writes                                       */
    /* -------------------------------------------- */

    /// @dev token id is incremented after add
    function test__AddToken_TokenIdIsIncremented() external {
        // cache starting token id
        uint256 currentTokenId = edition.currentToken();

        // add token
        vm.prank(users.creator_0);
        edition.add(addParams);

        // token id is incremented
        assertEq(edition.currentToken(), currentTokenId + 1);
    }

    /// @dev default price is set after add
    function test__AddToken_DefaultPriceIsSet() external {
        // add token
        vm.prank(users.creator_0);
        uint256 tokenId_ = edition.add(addParams);

        // default price is set
        assertEq(edition.defaultPrice(tokenId_), addParams.defaultPrice);
    }

    /// @dev default mint params are set after add
    function test__AddToken_DefaultMintParamsAreSet() external {
        // add token
        vm.prank(users.creator_0);
        uint256 tokenId_ = edition.add(addParams);

        assertEq(edition.defaultMintParams(tokenId_).defaultPrice, addParams.defaultPrice);
        assertEq(edition.defaultMintParams(tokenId_).mintStart, addParams.mintStart);
        assertEq(edition.defaultMintParams(tokenId_).mintEnd, addParams.mintEnd);
        assertEq(edition.defaultMintParams(tokenId_).gate, false);
    }

    /// @dev token uri is set after add
    function test__AddToken_UriIsSet() external {
        string memory newUri = "https://test.uri.com";

        // modify default add params
        addParams.tokenUri = newUri;

        // add token
        vm.prank(users.creator_0);
        uint256 tokenId_ = edition.add(addParams);

        assertEq(edition.uri(tokenId_), newUri);
    }

    /// @dev token creator is set after add
    function test__AddToken_CreatorIsSet() external {
        // modify default add params
        addParams.creator = users.creator_1;

        // create edition instance
        IRouxEdition edition_ = _createEdition(users.creator_1);

        // add token
        vm.prank(users.creator_1);
        uint256 tokenId_ = edition_.add(addParams);

        assertEq(edition_.creator(tokenId_), users.creator_1);
    }

    /// @dev token max supply is set after add
    function test__AddToken_MaxSupplyIsSet() external {
        uint128 maxSupply = 888;

        // modify default add params
        addParams.maxSupply = maxSupply;

        // add token
        vm.prank(users.creator_0);
        uint256 tokenId_ = edition.add(addParams);

        assertEq(edition.maxSupply(tokenId_), maxSupply);
    }

    /// @dev token is minted to creator after add
    function test__AddToken_TokenIsMintedToCreator() external {
        // add token
        vm.prank(users.creator_0);
        uint256 tokenId_ = edition.add(addParams);

        assertEq(edition.balanceOf(users.creator_0, tokenId_), 1);
        assertEq(edition.totalSupply(tokenId_), 1);
    }

    /// @dev event is emitted when token is added
    function test__AddToken_EventIsEmitted() external {
        // get new edition instance
        IRouxEdition edition_ = _createEdition(users.creator_1);

        // expect emit
        vm.expectEmit({ emitter: address(edition_) });
        emit TokenAdded(1);

        // add token
        vm.prank(users.creator_1);
        edition_.add(addParams);
    }
}
