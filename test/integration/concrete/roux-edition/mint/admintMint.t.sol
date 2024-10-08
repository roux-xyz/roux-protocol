// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract AdminMint_RouxEdition_Unit_Concrete_Test is BaseTest {
    EditionData.AddParams addParams;

    function setUp() public override {
        BaseTest.setUp();
        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when non-owner tries to mint
    function test__RevertWhen_AdminMint_NonOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.adminMint(user, 1, 1, "");
    }

    /// @dev reverts when token id is 0
    function test__RevertWhen_AdminMint_TokenIdIsZero() external {
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidTokenId.selector);
        edition.adminMint(user, 0, 1, "");
    }

    /// @dev reverts when token id does not exist
    function test__RevertWhen_AdminMint_TokenIdDoesNotExist() external {
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidTokenId.selector);
        edition.adminMint(user, 2, 1, "");
    }

    /// @dev reverts when max supply is already minted
    function test__RevertWhen_AdminMint_MaxSupplyIsAlreadyMinted() external {
        addParams.maxSupply = 1;

        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_MaxSupplyExceeded.selector);
        edition.adminMint(user, tokenId_, 1, "");
    }

    /// @dev reverts when token has parent
    function test__RevertWhen_AdminMint_TokenHasParent() external {
        (RouxEdition fork_, uint256 tokenId_) = _createFork(edition, 1, creator);

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_HasParent.selector);
        fork_.adminMint(user, tokenId_, 1, "");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully mints token as owner
    function test__AdminMint() external {
        vm.prank(creator);
        edition.adminMint(user, 1, 1, "");

        assertEq(edition.balanceOf(user, 1), 1);
        assertEq(edition.totalSupply(1), 2);
    }

    /// @dev mints multiple quantity of tokens
    function test__AdminMint_MultipleTokens() external {
        vm.prank(creator);
        edition.adminMint(user, 1, 2, "");

        assertEq(edition.balanceOf(user, 1), 2);
        assertEq(edition.totalSupply(1), 3);
    }

    /// @dev mint event is emitted
    function test__AdminMint_EventEmits() external {
        vm.expectEmit({ emitter: address(edition) });
        emit TransferSingle({ operator: creator, from: address(0), to: user, id: 1, amount: 1 });

        vm.prank(creator);
        edition.adminMint(user, 1, 1, "");
    }
}
