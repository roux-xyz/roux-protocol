// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract SupportsInterface_RouxEdition_Unit_Concrete_Test is BaseTest {
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
    }

    /* -------------------------------------------- */
    /* tests                                        */
    /* -------------------------------------------- */

    /// @dev tests if RouxEdition supports IRouxEdition interface
    function test__SupportsInterface_IRouxEdition() external view {
        assertTrue(edition.supportsInterface(type(IRouxEdition).interfaceId));
    }

    /// @dev tests if RouxEdition supports IERC165 interface
    function test__SupportsInterface_IERC165() external view {
        assertTrue(edition.supportsInterface(type(IERC165).interfaceId));
    }

    /// @dev tests if RouxEdition supports IERC1155 interface
    function test__SupportsInterface_IERC1155() external view {
        assertTrue(edition.supportsInterface(type(IERC1155).interfaceId));
    }

    /// @dev tests if RouxEdition does not support a random interface
    function test__DoesNotSupportInterface_Random() external view {
        bytes4 randomInterfaceId = bytes4(keccak256("randomInterface()"));
        assertFalse(edition.supportsInterface(randomInterfaceId));
    }
}
