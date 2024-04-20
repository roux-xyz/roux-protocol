// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { BaseEditionMinter } from "src/minters/BaseEditionMinter.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";

/**
 * @title Default Edition Minter
 * @author Roux
 */
contract DefaultEditionMinter is BaseEditionMinter {
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

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice fixed price
     */
    uint128 internal constant PRICE = 0.0005 ether;

    /**
     * @notice default edition minter storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("defaultEditionMinter.defaultEditionMinterStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant DEFAULT_EDITION_MINTER_STORAGE_SLOT =
        0x7c36ff87dcc3473c01bcaad4bca9e7e28759ded4ee6103be6f52472da9ebf500;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice mint info
     * @param mintStart mint start time
     * @param mintEnd mint end time
     */
    struct MintInfo {
        uint40 mintStart;
        uint40 mintEnd;
    }

    /**
     * @notice default edition minter storage
     * @custom:storage-location erc7201:defaultEditionMinter.defaultEditionMinterStorage
     *
     * @param initialized whether the contract has been initialized
     * @param mintInfo mapping of edition -> id -> mint info
     */
    struct DefaultEditionMinterStorage {
        bool initialized;
        mapping(address edition => mapping(uint256 id => MintInfo tokenMintInfo)) mintInfo;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    /**
     * @notice constructor
     * @param controller roux controller
     */
    constructor(address controller) BaseEditionMinter(controller) {
        DefaultEditionMinterStorage storage $ = _storage();

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
     * @notice initialize RouxEditionFactory
     */
    function initialize() external {
        DefaultEditionMinterStorage storage $ = _storage();

        require(!$.initialized, "Already initialized");
        $.initialized = true;

        /* Set owner of proxy */
        _initializeOwner(msg.sender);
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice get default edition minter storage location
     * @return $ DefaultEditionMinterStorage storage location
     */
    function _storage() internal pure returns (DefaultEditionMinterStorage storage $) {
        assembly {
            $.slot := DEFAULT_EDITION_MINTER_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function price(address, /* edition */ uint256 /* id */ ) external pure override returns (uint128) {
        return PRICE;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function setMintParams(uint256 id, bytes calldata params) external {
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
     * @param quantity quantity
     */
    function _beforeTokenTransfer(
        address, /* to */
        address edition,
        uint256 id,
        uint256 quantity,
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

        // verify sufficient funds
        if (msg.value < PRICE * quantity) revert InsufficientFunds();
    }
}
