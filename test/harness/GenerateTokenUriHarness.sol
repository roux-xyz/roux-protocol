// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { RouxEdition } from "src/core/RouxEdition.sol";
import { IRouxEditionFactory } from "src/core/interfaces/IRouxEditionFactory.sol";
import { ICollectionFactory } from "src/core/interfaces/ICollectionFactory.sol";
import { IController } from "src/core/interfaces/IController.sol";
import { IRegistry } from "src/core/interfaces/IRegistry.sol";
import { TokenUriLib } from "src/libraries/TokenUriLib.sol";

contract GenerateTokenUriHarness is RouxEdition {
    using TokenUriLib for bytes32;

    constructor(
        address editionFactory_,
        address collectionFactory_,
        address controller_,
        address registry_
    )
        RouxEdition(editionFactory_, collectionFactory_, controller_, registry_)
    { }

    function generateTokenUri(bytes32 digest) public pure returns (string memory) {
        return digest.generateTokenUri();
    }
}
