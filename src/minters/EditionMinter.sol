// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

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
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice edition minter storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("editionMinter.EditionMinterStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant EDITION_MINTER_STORAGE_SLOT =
        0x3c7a207398ddd2f021fb7a4bbb30885545bdcf0f21488ce720cd5be6123bb700;

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

    /**
     * @notice edition minter storage
     * @custom:storage-location erc7201:editionMinter.EditionMinterStorage
     *
     * @param initialized whether the contract has been initialized
     * @param mintInfo mapping of edition -> id -> mint info
     * @param balance mapping of account -> edition -> id -> balance
     */
    struct EditionMinterStorage {
        bool initialized;
        mapping(address edition => mapping(uint256 id => MintInfo tokenMintInfo)) mintInfo;
        mapping(address account => mapping(address edition => mapping(uint256 id => uint16 balance))) balance;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    /**
     * @notice constructor
     * @param controller roux controller
     */
    constructor(address controller) BaseEditionMinter(controller) {
        EditionMinterStorage storage $ = _storage();

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
     * @notice initialize edition minter
     */
    function initialize() external {
        EditionMinterStorage storage $ = _storage();

        require(!$.initialized, "Already initialized");
        $.initialized = true;

        /* Set owner of proxy */
        _initializeOwner(msg.sender);
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice get edition minter storage location
     * @return $ EditionMinterStorage storage location
     */
    function _storage() internal pure returns (EditionMinterStorage storage $) {
        assembly {
            $.slot := EDITION_MINTER_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function price(address edition, uint256 id) external view override returns (uint128) {
        return _storage().mintInfo[edition][id].price;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function setMintParams(uint256 id, bytes calldata params) external {
        // includes padding
        if (params.length != 128) revert InvalidParamsLength();

        // decode params
        MintInfo memory mintInfo = abi.decode(params, (MintInfo));

        // validate mint info
        if (mintInfo.mintStart >= mintInfo.mintEnd) revert InvalidMintParams();

        // set mint info
        _storage().mintInfo[msg.sender][id] = mintInfo;

        emit MintParamsUpdated(id, params);
    }

    /* -------------------------------------------- */
    /* internal functions                           */
    /* -------------------------------------------- */

    /**
     * @notice before mint
     * @param to address receiving minted tokens
     * @param edition edition
     * @param id token id
     * @param quantity quantity
     */
    function _beforeTokenTransfer(
        address to,
        address edition,
        uint256 id,
        uint256 quantity,
        bytes memory
    )
        internal
        override
    {
        EditionMinterStorage storage $ = _storage();
        MintInfo storage mintInfo = $.mintInfo[edition][id];

        // verify mint is active
        if (block.timestamp < mintInfo.mintStart) revert MintNotStarted();
        if (block.timestamp > mintInfo.mintEnd) revert MintEnded();

        // verify quantity does not exceed max mintable by single address
        if ($.balance[to][edition][id] + quantity > mintInfo.maxMintable) {
            revert MaxMintableExceeded();
        }

        // verify sufficient funds
        if (msg.value < mintInfo.price * quantity) revert InsufficientFunds();
    }
}
