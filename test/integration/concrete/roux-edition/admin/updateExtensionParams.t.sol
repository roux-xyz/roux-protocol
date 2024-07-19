// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";

contract UpdateExtensionParams_RouxEdition_Integration_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                       */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when not owner
    function test__RevertWhen_UpdateExtensionParams_NotOwner() external {
        vm.prank(users.user_0);
        vm.expectRevert(Ownable.Unauthorized.selector);
        edition.updateExtensionParams(1, address(mockExtension), abi.encode(1));
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates extension params
    function test__UpdateExtensionParams() external {
        uint128 customPrice = 5 * 10 ** 5; // $0.50 USDC

        // add extension to token
        vm.prank(users.creator_0);
        edition.setExtension(1, address(mockExtension), true, "");

        // expect event to be emitted
        vm.expectEmit({ emitter: address(mockExtension) });
        emit MintParamsUpdated(address(edition), 1, abi.encode(customPrice));

        // update extension params
        vm.prank(users.creator_0);
        edition.updateExtensionParams(1, address(mockExtension), abi.encode(customPrice));

        assertEq(mockExtension.price(address(edition), 1), customPrice);
    }
}
