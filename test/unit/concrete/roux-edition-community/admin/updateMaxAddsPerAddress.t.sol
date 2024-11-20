// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { BaseTest } from "test/Base.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { RouxCommunityEdition } from "src/core/RouxCommunityEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";

contract UpdateMaxAddsPerAddress_RouxCommunityEdition_Unit_Concrete_Test is BaseTest {
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
        RouxCommunityEdition(address(communityEdition)).updateMaxAddsPerAddress(2);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @dev successfully updates max adds per address
    function test__UpdateMaxAddsPerAddress() external {
        uint32 newMaxAdds = 2;

        vm.prank(creator);
        RouxCommunityEdition(address(communityEdition)).updateMaxAddsPerAddress(newMaxAdds);

        assertEq(RouxCommunityEdition(address(communityEdition)).maxAddsPerAddress(), newMaxAdds);

        vm.prank(users.creator_2);
        communityEdition.add(addParams);

        vm.prank(users.creator_2);
        communityEdition.add(addParams);
    }
}
