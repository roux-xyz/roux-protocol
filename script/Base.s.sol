// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";

/**
 * @notice Base deployment script
 */
contract BaseScript is Script {
    uint256 internal _broadcaster;
    mapping(uint256 => string) internal _chainIdToNetwork;

    /*--------------------------------------------------------------------------*/
    /* Constructor                                                              */
    /*--------------------------------------------------------------------------*/

    constructor() {
        try vm.envUint("PRIVATE_KEY") returns (uint256 value) {
            _broadcaster = value;
        } catch { }

        _chainIdToNetwork[1] = "mainnet";
        _chainIdToNetwork[11155111] = "sepolia";
        _chainIdToNetwork[31337] = "local";
    }

    modifier broadcast() {
        if (_broadcaster != 0) {
            vm.startBroadcast(_broadcaster);
        } else {
            vm.startBroadcast();
        }

        _;

        vm.stopBroadcast();
    }
}
