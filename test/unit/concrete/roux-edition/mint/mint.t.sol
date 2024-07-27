// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { IEditionExtension } from "src/interfaces/IEditionExtension.sol";
import { RouxEdition } from "src/RouxEdition.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

contract Mint_RouxEdition_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    EditionData.AddParams addParams;

    function setUp() public override {
        BaseTest.setUp();
        addParams = defaultAddParams;

        vm.prank(user);
        mockUSDC.approve(address(edition), type(uint256).max);
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when token id is 0
    function test__RevertWhen_Mint_TokenIdIsZero() external {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidTokenId.selector);
        edition.mint(user, 0, 1, address(0), address(0), "");
    }

    /// @dev reverts when token id does not exist
    function test__RevertWhen_Mint_TokenIdDoesNotExist() external {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidTokenId.selector);
        edition.mint(user, 2, 1, address(0), address(0), "");
    }

    /// @dev reverts when max supply is already minted
    function test__RevertWhen_Mint_MaxSupplyIsAlreadyMinted() external {
        addParams.maxSupply = 1;

        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_MaxSupplyExceeded.selector);
        edition.mint(user, tokenId_, 1, address(0), address(0), "");
    }

    /// @dev reverts when mint is gated and extension not provided
    function test__RevertWhen_Mint_GatedAndNoExtension() external {
        addParams.gate = true;

        vm.prank(creator);
        uint256 tokenId_ = edition.add(addParams);

        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_GatedMint.selector);
        edition.mint(user, tokenId_, 1, address(0), address(0), "");
    }

    /// @dev reverts when included extension is not registered
    function test__RevertWhen_Mint_InvalidExtension() external {
        vm.prank(user);
        vm.expectRevert(ErrorsLib.RouxEdition_InvalidExtension.selector);
        edition.mint(user, 1, 1, address(mockExtension), address(0), "");
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev mints token
    function test__Mint() external {
        // cache starting user balance
        uint256 startingUserBalance = mockUSDC.balanceOf(user);
        uint256 startingCreatorControllerBalance = _getUserControllerBalance(creator);

        vm.prank(user);
        edition.mint(user, 1, 1, address(0), address(0), "");

        assertEq(edition.balanceOf(user, 1), 1);
        assertEq(edition.totalSupply(1), 2);

        // verify user balance
        assertEq(mockUSDC.balanceOf(user), startingUserBalance - addParams.defaultPrice);
        assertEq(_getUserControllerBalance(creator), startingCreatorControllerBalance + addParams.defaultPrice);
    }

    /// @dev mints multiple quantity of tokens
    function test__Mint_MultipleTokens() external {
        vm.prank(user);
        edition.mint(user, 1, 2, address(0), address(0), "");

        assertEq(edition.balanceOf(user, 1), 2);
        assertEq(edition.totalSupply(1), 3);
    }

    /// @dev mint event is emitted
    function test__Mint_EventEmits() external {
        vm.prank(user);
        mockUSDC.approve(address(edition), type(uint256).max);

        vm.expectEmit({ emitter: address(edition) });
        emit TransferSingle({ operator: user, from: address(0), to: user, id: 1, amount: 1 });

        vm.prank(user);
        edition.mint(user, 1, 1, address(0), address(0), "");
    }
}
