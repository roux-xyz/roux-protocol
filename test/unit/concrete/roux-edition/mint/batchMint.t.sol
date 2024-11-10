// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { IExtension } from "src/periphery/interfaces/IExtension.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

contract BatchMint_RouxEdition_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    EditionData.AddParams addParams;
    uint256[] ids;
    uint256[] quantities;
    address[] extensions;

    function setUp() public override {
        BaseTest.setUp();
        addParams = defaultAddParams;

        vm.prank(user);
        mockUSDC.approve(address(edition), type(uint256).max);

        // Add multiple tokens
        for (uint256 i = 0; i < 3; i++) {
            _addToken(edition);
        }

        ids = [1, 2, 3];
        quantities = [1, 2, 1];
        extensions = new address[](3);
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when array lengths mismatch
    function test__RevertWhen_BatchMint_ArrayLengthsMismatch() external {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidParams.selector);
        edition.batchMint(user, ids, new uint256[](2), extensions, address(0), "");
    }

    /// @dev reverts when token id does not exist
    function test__RevertWhen_BatchMint_TokenIdDoesNotExist() external {
        ids[1] = 99;
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidTokenId.selector);
        edition.batchMint(user, ids, quantities, extensions, address(0), "");
    }

    /// @dev reverts when max supply is exceeded for any token
    function test__RevertWhen_BatchMint_MaxSupplyExceeded() external {
        // mint additional mockUSDC to user
        mockUSDC.mint(user, 5000 * 10 ** 6);

        addParams.maxSupply = 1000;
        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        ids[1] = tokenId_;

        quantities[1] = 1001;

        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_MaxSupplyExceeded.selector);
        edition.batchMint(user, ids, quantities, extensions, address(0), "");
    }

    /// @dev reverts when mint is gated and no extension provided
    function test__RevertWhen_BatchMint_GatedAndNoExtension() external {
        addParams.gate = true;
        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        ids[2] = tokenId_;
        extensions[2] = address(0);

        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_GatedMint.selector);
        edition.batchMint(user, ids, quantities, extensions, address(0), "");
    }

    /// @dev reverts when invalid extension is provided
    function test__RevertWhen_BatchMint_InvalidExtension() external {
        extensions[1] = address(0x123);
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidExtension.selector);
        edition.batchMint(user, ids, quantities, extensions, address(0), "");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev batch mints tokens
    function test__BatchMint() external {
        uint256 startingUserBalance = mockUSDC.balanceOf(user);
        uint256 startingCreatorControllerBalance = _getUserControllerBalance(creator);

        vm.prank(user);
        edition.batchMint(user, ids, quantities, extensions, address(0), "");

        assertEq(edition.balanceOf(user, 1), 1);
        assertEq(edition.balanceOf(user, 2), 2);
        assertEq(edition.balanceOf(user, 3), 1);
        assertEq(edition.totalSupply(1), 2);
        assertEq(edition.totalSupply(2), 3);
        assertEq(edition.totalSupply(3), 2);

        uint256 totalPrice = TOKEN_PRICE * (quantities[0] + quantities[1] + quantities[2]);
        assertEq(mockUSDC.balanceOf(user), startingUserBalance - totalPrice);
        assertEq(_getUserControllerBalance(creator), startingCreatorControllerBalance + totalPrice);
    }

    /// @dev batch mint emits correct events
    function test__BatchMint_EventsEmitted() external {
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(user, address(0), user, ids, quantities);

        vm.prank(user);
        edition.batchMint(user, ids, quantities, extensions, address(0), "");
    }
}
