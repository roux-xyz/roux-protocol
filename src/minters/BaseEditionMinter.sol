// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { Ownable } from "solady/auth/Ownable.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";
import { IController } from "src/interfaces/IController.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";

/**
 * @title Base Minter
 * @author Roux
 */
abstract contract BaseEditionMinter is IEditionMinter, Ownable {
    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice roux administrator
     */
    IController internal immutable _controller;

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    /**
     * @notice constructor
     * @param controller roux controller
     */
    constructor(address controller) {
        // set attribution manager
        _controller = IController(controller);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function mint(
        address to,
        address edition,
        uint256 id,
        uint256 quantity,
        bytes memory data
    )
        external
        payable
        virtual
    {
        // before token transfer
        _beforeTokenTransfer(to, edition, id, quantity, data);

        // mint via edition contract
        IRouxEdition(edition).mint(to, id, quantity, data);

        // disburse funds
        _controller.disburse{ value: msg.value }(edition, id);

        // after token transfer
        _afterTokenTransfer(to, edition, id, quantity, data);
    }

    /**
     * @inheritdoc IEditionMinter
     */
    function price(address edition, uint256 id) external view virtual returns (uint128);

    /* -------------------------------------------- */
    /* internal functions                           */
    /* -------------------------------------------- */

    /**
     * @notice internal function to handle validation and state updates  before mint
     * @param to address receiving minted tokens
     * @param edition edition
     * @param id token id
     * @param quantity quantity
     *
     * @dev must be implemented by inheriting contracts
     */
    function _beforeTokenTransfer(
        address to,
        address edition,
        uint256 id,
        uint256 quantity,
        bytes memory data
    )
        internal
        virtual;

    /**
     * @notice internal function to handle validation and state updates after mint
     * @param to address receiving minted tokens
     * @param edition edition
     * @param id token id
     * @param quantity quantity
     *
     * @dev can be overridden by inheriting contracts
     */
    function _afterTokenTransfer(
        address to,
        address edition,
        uint256 id,
        uint256 quantity,
        bytes memory data
    )
        internal
        virtual
    { }

    /* -------------------------------------------- */
    /* supports interface                           */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IEditionMinter).interfaceId;
    }

    /* -------------------------------------------- */
    /* proxy | danger zone                          */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc IEditionMinter
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external onlyOwner {
        ERC1967Utils.upgradeToAndCall(newImplementation, data);
    }
}
