pragma solidity ^0.8.0;

/**
 * @title Base32 encoding library
 * @author Modified from (https://github.com/0x00000002/ipfs-cid-solidity/blob/main/contracts/Base32.sol)
 */
library Base32 {
    bytes internal constant _ALPHABET = "abcdefghijklmnopqrstuvwxyz234567";

    /**
     * @notice encodes bytes data into a Base32 string
     * @param data the bytes data to encode
     * @return the Base32 encoded string
     */
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 dataLength = data.length;

        // return an empty string if data is empty
        if (dataLength == 0) {
            return "";
        }

        // calculate the length of the encoded string
        // each 5-byte block of data becomes 8 Base32 characters
        uint256 encodedLength = (dataLength * 8 + 4) / 5;

        // initialize a bytes array to hold the encoded characters
        bytes memory encoded = new bytes(encodedLength);

        uint256 dataIndex;
        uint256 encodedIndex;
        uint40 buffer;
        uint8 bitsLeft;

        while (dataIndex < dataLength) {
            buffer <<= 8; // shift buffer to the left by 1 byte (8 bits)
            buffer |= uint8(data[dataIndex++]); // add the next byte to buffer
            bitsLeft += 8;

            // extract as many 5-bit chunks as possible
            while (bitsLeft >= 5) {
                bitsLeft -= 5;
                uint8 index = uint8((buffer >> bitsLeft) & 0x1F);
                encoded[encodedIndex++] = _ALPHABET[index];
            }
        }

        // handle remaining bits (if any)
        if (bitsLeft > 0) {
            buffer <<= (5 - bitsLeft);
            uint8 index = uint8(buffer & 0x1F);
            encoded[encodedIndex++] = _ALPHABET[index];
        }

        return string(encoded);
    }
}
