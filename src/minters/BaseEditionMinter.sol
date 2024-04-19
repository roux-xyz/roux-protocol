// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";
import { IController } from "src/interfaces/IController.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";

/**
 * @title Base Minter
 * @author Roux
 */
abstract contract BaseEditionMinter is IEditionMinter {
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
        // validate mint
        _validateMint(to, edition, id, quantity, data);

        // mint via edition contract
        IRouxEdition(edition).mint(to, id, quantity, data);

        // disburse funds
        _controller.disburse{ value: msg.value }(edition, id);
    }

    /**
     * @inheritdoc IEditionMinter
     */
    function price(address edition, uint256 id) external view virtual returns (uint128);

    /* -------------------------------------------- */
    /* internal functions                           */
    /* -------------------------------------------- */

    /**
     * @notice internal function to validate mint
     * @param to address receiving minted tokens
     * @param edition edition
     * @param id token id
     * @param quantity quantity
     */
    function _validateMint(
        address to,
        address edition,
        uint256 id,
        uint256 quantity,
        bytes memory data
    )
        internal
        virtual;
}
