// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ERC6551 } from "solady/accounts/ERC6551.sol";

/**
 * @title erc6551 account
 * @author roux
 * @custom:version 1.0
 * @custom:security-contact mp@roux.app
 */
contract ERC6551Account is ERC6551 {
    /// @dev returns the domain name and version of the contract for EIP712
    function _domainNameAndVersion()
        internal
        view
        virtual
        override
        returns (string memory name, string memory version)
    {
        name = "Roux ERC6551 Account";
        version = "0.1";
    }
}
