// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

contract AdminBatchMint_RouxEdition_Integration_Concrete_Test is BaseTest {
    EditionData.AddParams addParams;
    uint256[] ids;
    uint256[] quantities;

    function setUp() public override {
        BaseTest.setUp();
        addParams = defaultAddParams;

        // Add multiple tokens
        for (uint256 i = 0; i < 3; i++) {
            _addToken(edition);
        }

        ids = [1, 2, 3];
        quantities = [1, 2, 1];
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when non-owner tries to batch mint
    function test__RevertWhen_AdminBatchMint_NonOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.adminBatchMint(user, ids, quantities, "");
    }

    /// @dev reverts when array lengths mismatch
    function test__RevertWhen_AdminBatchMint_ArrayLengthsMismatch() external {
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidParams.selector);
        edition.adminBatchMint(user, ids, new uint256[](2), "");
    }

    /// @dev reverts when token id is 0
    function test__RevertWhen_AdminBatchMint_TokenIdIsZero() external {
        ids[1] = 0;
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidTokenId.selector);
        edition.adminBatchMint(user, ids, quantities, "");
    }

    /// @dev reverts when token id does not exist
    function test__RevertWhen_AdminBatchMint_TokenIdDoesNotExist() external {
        ids[1] = 99;
        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidTokenId.selector);
        edition.adminBatchMint(user, ids, quantities, "");
    }

    /// @dev reverts when max supply is exceeded for any token
    function test__RevertWhen_AdminBatchMint_MaxSupplyExceeded() external {
        addParams.maxSupply = 1;
        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        ids[1] = tokenId_;
        quantities[1] = 2;

        vm.prank(creator);
        vm.expectRevert(ErrorsLib.RouxEdition_MaxSupplyExceeded.selector);
        edition.adminBatchMint(user, ids, quantities, "");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully batch mints tokens as owner
    function test__AdminBatchMint() external {
        vm.prank(creator);
        edition.adminBatchMint(user, ids, quantities, "");

        assertEq(edition.balanceOf(user, 1), 1);
        assertEq(edition.balanceOf(user, 2), 2);
        assertEq(edition.balanceOf(user, 3), 1);
        assertEq(edition.totalSupply(1), 2);
        assertEq(edition.totalSupply(2), 3);
        assertEq(edition.totalSupply(3), 2);
    }

    /// @dev batch mint events are emitted
    function test__AdminBatchMint_EventEmits() external {
        vm.expectEmit({ emitter: address(edition) });
        emit TransferBatch(creator, address(0), user, ids, quantities);

        vm.prank(creator);
        edition.adminBatchMint(user, ids, quantities, "");
    }
}
