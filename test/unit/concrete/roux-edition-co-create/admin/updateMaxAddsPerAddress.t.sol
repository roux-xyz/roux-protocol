// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { RouxEditionCoCreate } from "src/core/RouxEditionCoCreate.sol";
import { EditionData } from "src/types/DataTypes.sol";

contract UpdateMaxAddsPerAddress_RouxEditionCoCreate_Unit_Concrete_Test is BaseTest {
    EditionData.AddParams addParams;
    /* -------------------------------------------- */
    /* setup                                        */
    /* -------------------------------------------- */

    function setUp() public override {
        BaseTest.setUp();
        addParams = defaultAddParams;
    }

    /* -------------------------------------------- */
    /* reverts                                      */
    /* -------------------------------------------- */

    /// @dev reverts when not owner
    function test__RevertWhen_UpdateMaxAddsPerAddress_NotOwner() external {
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        RouxEditionCoCreate(address(coCreateEdition)).updateMaxAddsPerAddress(2);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates max adds per address
    function test__UpdateMaxAddsPerAddress() external {
        uint32 newMaxAdds = 2;

        vm.prank(creator);
        RouxEditionCoCreate(address(coCreateEdition)).updateMaxAddsPerAddress(newMaxAdds);

        assertEq(RouxEditionCoCreate(address(coCreateEdition)).maxAddsPerAddress(), newMaxAdds);

        vm.prank(users.creator_2);
        coCreateEdition.add(addParams);

        vm.prank(users.creator_2);
        coCreateEdition.add(addParams);
    }
}
