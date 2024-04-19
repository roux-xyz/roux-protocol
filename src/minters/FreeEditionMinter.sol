// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { BaseEditionMinter } from "src/minters/BaseEditionMinter.sol";

import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";
import { ERC1155 } from "solady/tokens/ERC1155.sol";

/**
 * @title Default Edition Minter
 * @author Roux
 */
contract FreeEditionMinter is BaseEditionMinter {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    /**
     * @notice mint not started
     */
    error MintNotStarted();

    /**
     * @notice mint ended
     */
    error MintEnded();

    /**
     * @notice already minted
     */
    error AlreadyMinted();

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice sale data
     */
    struct MintInfo {
        uint40 mintStart;
        uint40 mintEnd;
    }

    /* -------------------------------------------- */
    /* state                                        */
    /* -------------------------------------------- */

    /**
     * @notice mint info
     */
    mapping(address edition => mapping(uint256 id => MintInfo tokenMintInfo)) internal _mintInfo;

    /**
     * @notice hasMinted
     */
    mapping(address edition => mapping(uint256 id => bool hasMinted)) internal _hasMinted;

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
    function price(address, /* edition */ uint256 /* id */ ) external view override returns (uint128) {
        return 0;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function setMintParams(uint256 id, bytes calldata params) external override {
        // includes padding
        if (params.length != 64) revert InvalidParamsLength();

        // decode mint params
        MintInfo memory mintInfo = abi.decode(params, (MintInfo));

        // validate mint info
        if (mintInfo.mintStart >= mintInfo.mintEnd) revert InvalidMintParams();

        // set mint info
        _mintInfo[msg.sender][id] = mintInfo;
    }

    /* -------------------------------------------- */
    /* internal functions                           */
    /* -------------------------------------------- */

    /**
     * @notice validate mint
     * @param edition edition
     * @param id token id
     */
    function _validateMint(
        address, /* to */
        address edition,
        uint256 id,
        uint256, /* quantity */
        bytes memory
    )
        internal
        override
    {
        // verify token id
        MintInfo storage saleData = _mintInfo[edition][id];

        // verify mint is active
        if (block.timestamp < saleData.mintStart) revert MintNotStarted();
        if (block.timestamp > saleData.mintEnd) revert MintEnded();

        // check if already minted
        if (_hasMinted[edition][id]) revert AlreadyMinted();
    }
}
