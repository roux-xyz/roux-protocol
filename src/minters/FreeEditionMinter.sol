// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";
import { BaseEditionMinter } from "src/minters/BaseEditionMinter.sol";

/**
 * @title Free Edition Minter
 * @author Roux
 *
 * @dev free mint for a single token (enforced in minter contract)
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
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice free edition minter storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("freeEditionMinter.freeEditionMinterStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant FREE_EDITION_MINTER_STORAGE_SLOT =
        0xa170b401f374bc75f7320eed7c51f70492055d8f789ed55d3f9b90bce78f8f00;

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

    /**
     * @notice free edition minter storage
     * @custom:storage-location erc7201:freeEditionMinter.freeEditionMinterStorage
     *
     * @param initialized whether the contract has been initialized
     * @param mintInfo mapping of edition -> id -> mint info
     */
    struct FreeEditionMinterStorage {
        bool initialized;
        mapping(address edition => mapping(uint256 id => MintInfo tokenMintInfo)) mintInfo;
        mapping(address account => mapping(address edition => mapping(uint256 id => bool hasMinted))) hasMinted;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    /**
     * @notice constructor
     * @param controller roux controller
     */
    constructor(address controller) BaseEditionMinter(controller) {
        FreeEditionMinterStorage storage $ = _storage();

        /* disable initialization of implementation contract */
        require(!$.initialized, "Already initialized");
        $.initialized = true;

        /* renounce ownership of implementation contract */
        _initializeOwner(msg.sender);
        renounceOwnership();
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    /**
     * @notice initialize free edition minter
     */
    function initialize() external {
        FreeEditionMinterStorage storage $ = _storage();

        require(!$.initialized, "Already initialized");
        $.initialized = true;

        /* Set owner of proxy */
        _initializeOwner(msg.sender);
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice get free edition minter storage location
     * @return $ FreeEditionMinterStorage storage location
     */
    function _storage() internal pure returns (FreeEditionMinterStorage storage $) {
        assembly {
            $.slot := FREE_EDITION_MINTER_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function price(address, /* edition */ uint256 /* id */ ) external pure override returns (uint128) {
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
        _storage().mintInfo[msg.sender][id] = mintInfo;
    }

    /* -------------------------------------------- */
    /* internal functions                           */
    /* -------------------------------------------- */

    /**
     * @notice before mint
     * @param edition edition
     * @param id token id
     */
    function _beforeTokenTransfer(
        address to,
        address edition,
        uint256 id,
        uint256, /* quantity */
        bytes memory
    )
        internal
        override
    {
        // verify token id
        MintInfo storage saleData = _storage().mintInfo[edition][id];

        // verify mint is active
        if (block.timestamp < saleData.mintStart) revert MintNotStarted();
        if (block.timestamp > saleData.mintEnd) revert MintEnded();

        // check if already minted
        if (_storage().hasMinted[edition][to][id]) revert AlreadyMinted();

        // set has minted to true
        _storage().hasMinted[edition][to][id] = true;
    }
}
