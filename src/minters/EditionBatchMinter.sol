// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";
import { BaseEditionMinter } from "src/minters/BaseEditionMinter.sol";

/**
 * @title Edition Minter
 * @author Roux
 */
contract EditionBatchMinter is BaseEditionMinter {
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
     * @dev keccak256(abi.encode(uint256(keccak256("editionBatchMinter.EditionBatchMinterStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant EDITION_BATCH_MINTER_STORAGE_SLOT =
        0x42c6cccd5b9fd14ee0c3b09b6c90ff0d2260d9f10f0d535eb56b70850096f400;

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
        mapping(address edition => mapping(uint256 batchId => MintInfo tokenMintInfo)) mintInfo;
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
            $.slot := EDITION_BATCH_MINTER_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function price(address edition, uint256 batchId) external view override returns (uint128) {
        return _storage().mintInfo[edition][batchId].price;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IEditionMinter
     */
    function batchMint(
        address to,
        address edition,
        uint256[] memory ids,
        uint256[] memory quantities,
        bytes memory data
    )
        external
        payable
        override
    {
        // derive batchId
        uint256 batchId = uint256(keccak256(abi.encode(ids)));

        // before token transfer
        _beforeTokenTransfer(to, edition, batchId, 1, "");

        // mint via edition contract
        IRouxEdition(edition).batchMint(to, ids, quantities, data);

        // disburse funds
        uint256 derivedPrice = msg.value / ids.length;
        uint256 totalValue = msg.value;
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 allocatedPrice = totalValue < derivedPrice ? totalValue : derivedPrice;
            totalValue -= allocatedPrice;

            _controller.disburse{ value: allocatedPrice }(edition, ids[i]);
        }
    }

    /**
     * @inheritdoc IEditionMinter
     */
    function setMintParams(uint256 batchId, bytes calldata params) external {
        // includes zero padding
        if (params.length != 96) revert InvalidParamsLength();

        // decode params
        MintInfo memory mintInfo = abi.decode(params, (MintInfo));

        // validate mint info
        if (mintInfo.mintStart >= mintInfo.mintEnd) revert InvalidMintParams();

        // set mint info
        _storage().mintInfo[msg.sender][batchId] = mintInfo;

        emit MintParamsUpdated(batchId, params);
    }

    /**
     * @inheritdoc IEditionMinter
     */
    function mint(
        address, /* to */
        address, /* edition */
        uint256, /* id */
        uint256, /* quantity */
        bytes memory /* data */
    )
        external
        payable
        override
    {
        revert("Batch mint only");
    }

    /* -------------------------------------------- */
    /* internal functions                           */
    /* -------------------------------------------- */

    /**
     * @notice before mint
     * @param edition edition
     * @param batchId batch id
     */
    function _beforeTokenTransfer(
        address, /* to */
        address edition,
        uint256 batchId,
        uint256, /* quantity */
        bytes memory
    )
        internal
        override
    {
        EditionMinterStorage storage $ = _storage();
        MintInfo storage mintInfo = $.mintInfo[edition][batchId];

        // verify mint params exist
        if (mintInfo.mintEnd == 0) revert MintParamsNotSet();

        // verify mint is active
        if (block.timestamp < mintInfo.mintStart) revert MintNotStarted();
        if (block.timestamp > mintInfo.mintEnd) revert MintEnded();

        // verify sufficient funds
        if (msg.value < mintInfo.price) revert InsufficientFunds();
    }
}
