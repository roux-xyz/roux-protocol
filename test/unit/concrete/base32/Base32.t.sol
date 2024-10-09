// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import "src/libraries/Base32.sol";
import "forge-std/Test.sol";

contract Base32_Unit_Concrete_Test is Test {
    function test__Encode_EmptyInput() public pure {
        bytes memory data = "";
        string memory output = Base32.encode(data);
        string memory expected = "";
        assertEq(output, expected, "Empty input test failed");
    }

    function test__Encode() public pure {
        bytes memory data1 = "6E6FF7950A36187A801613426E858DCE686CD7D7E3C0FC42EE0330072D245C95";
        bytes memory data2 = "0x6E6FF7950A36187A801613426E858DCE686CD7D7E3C0FC42EE0330072D245C95";
        bytes memory encodedResult =
            "gzctmrsgg44tkmcbgm3dcobxie4damjwgeztimrwiu4dkoceinctmobwincdorbxiuzugmcgim2derkfgaztgmbqg4zeimrugvbtsni";

        string memory encoded = Base32.encode(data1);
        assertEq(encoded, string(encodedResult), "data1");

        encoded = Base32.encode(data2);
        assertNotEq(encoded, string(encodedResult), "data2");
    }
}
