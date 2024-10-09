// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { RouxEdition } from "src/RouxEdition.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { ICollectionFactory } from "src/interfaces/ICollectionFactory.sol";
import { IController } from "src/interfaces/IController.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";

contract GenerateTokenUriHarness is RouxEdition {
    constructor(
        address editionFactory_,
        address collectionFactory_,
        address controller_,
        address registry_
    )
        RouxEdition(editionFactory_, collectionFactory_, controller_, registry_)
    { }

    function generateTokenUri(bytes32 digest) public pure returns (string memory) {
        return _generateTokenUri(digest);
    }
}
