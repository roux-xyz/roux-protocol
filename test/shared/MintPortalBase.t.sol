// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import { CollectionBase } from "test/shared/CollectionBase.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { RouxEdition } from "src/core/RouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { REFERRAL_FEE, PLATFORM_FEE } from "src/libraries/FeesLib.sol";

/// @title ControllerBase test
abstract contract MintPortalBase is CollectionBase {
    address usdcDepositor;
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public virtual override {
        CollectionBase.setUp();

        usdcDepositor = users.usdcDepositor;
    }

    /* -------------------------------------------- */
    /* utility functions                            */
    /* -------------------------------------------- */

    /// @dev deposit USDC and mint rUSDC
    function _depositUsdc(address to, uint256 amount) internal {
        vm.startPrank(usdcDepositor);
        mockUSDC.approve(address(mintPortal), amount);
        mintPortal.deposit(to, amount);
        vm.stopPrank();
    }

    /// @dev mint promotional tokens
    function _mintPromotionalTokens(address to, uint256 tokenId, uint256 quantity) internal {
        vm.prank(users.deployer);
        mintPortal.mintPromotionalTokens(to, tokenId, quantity);
    }
}
