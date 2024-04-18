// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC1155 } from "solady/tokens/ERC1155.sol";

import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";
import { BaseEditionMinter } from "src/minters/BaseEditionMinter.sol";

/**
 * @title Edition Minter
 * @author Roux
 */
contract EditionMinter is BaseEditionMinter {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    /**
     * @notice max mintable exceeded
     */
    error MaxMintableExceeded();

    /**
     * @notice mint not started
     */
    error MintNotStarted();

    /**
     * @notice mint ended
     */
    error MintEnded();

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice mint info
     */
    struct MintInfo {
        uint128 price;
        uint40 mintStart;
        uint40 mintEnd;
        uint16 maxMintable;
    }

    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    /**
     * @notice mint info
     */
    mapping(address edition => mapping(uint256 id => MintInfo tokenMintInfo)) internal _mintInfo;

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    /**
     * @notice constructor
     * @param administrator roux administrator
     */
    constructor(address administrator) BaseEditionMinter(administrator) { }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function price(address edition, uint256 id) external view override returns (uint128) {
        return _mintInfo[edition][id].price;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function setMintParams(uint256 id, bytes calldata params) external override {
        // includes padding
        if (params.length != 128) revert InvalidParamsLength();

        // decode params
        MintInfo memory mintInfo = abi.decode(params, (MintInfo));

        // validate mint info
        if (mintInfo.mintStart >= mintInfo.mintEnd) revert InvalidMintParams();

        // set mint info
        _mintInfo[msg.sender][id] = mintInfo;

        emit MintParamsUpdated(id, params);
    }

    /* -------------------------------------------- */
    /* internal functions                           */
    /* -------------------------------------------- */

    /**
     * @notice validate mint
     * @param to address receiving minted tokens
     * @param edition edition
     * @param id token id
     * @param quantity quantity
     */
    function _validateMint(address to, address edition, uint256 id, uint256 quantity, bytes memory) internal override {
        MintInfo storage mintInfo = _mintInfo[edition][id];

        // verify mint is active
        if (block.timestamp < mintInfo.mintStart) revert MintNotStarted();
        if (block.timestamp > mintInfo.mintEnd) revert MintEnded();

        // verify quantity does not exceed max mintable by single address
        if (ERC1155(edition).balanceOf(to, id) + quantity > mintInfo.maxMintable) {
            revert MaxMintableExceeded();
        }

        // verify sufficient funds
        if (msg.value < mintInfo.price * quantity) revert InsufficientFunds();
    }
}
