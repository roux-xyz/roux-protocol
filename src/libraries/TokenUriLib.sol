// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import { Base32 } from "./Base32.sol";

library TokenUriLib {
    /**
     * @notice generate token uri from IPFS digest
     * @param digest ipfs digest
     * @return token uri
     */
    function generateTokenUri(bytes32 digest) internal pure returns (string memory) {
        bytes memory cidBytes = new bytes(36);

        cidBytes[0] = 0x01; // cid version 1
        cidBytes[1] = 0x55; // multicodec raw binary
        cidBytes[2] = 0x12; // multihash function code for sha-256
        cidBytes[3] = 0x20; // multihash digest size

        // copy digest into cidBytes
        for (uint256 i = 0; i < 32; i++) {
            cidBytes[i + 4] = digest[i];
        }

        string memory encoded = Base32.encode(cidBytes);

        return string(abi.encodePacked("ipfs://b", encoded));
    }
}
