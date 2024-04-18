// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IRouxAdministrator } from "src/interfaces/IRouxAdministrator.sol";
import { IEditionMinter } from "src/interfaces/IEditionMinter.sol";

/**
 * @title Roux Edition
 * @author Roux
 */
contract RouxEdition is IRouxEdition, ERC1155, OwnableRoles {
    using SafeCast for uint256;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice RouxEdition storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxEdition.rouxEditionStorage")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_EDITION_STORAGE_SLOT =
        0xef2f5668c8b56b992983464f11901aec8635a37d61a520221ade259ca1a88200;

    /**
     * @notice implementation version
     */
    string public constant IMPLEMENTATION_VERSION = "1.0";

    /**
     * @notice minter role
     */
    uint256 public constant MINTER_ROLE = _ROLE_1;

    /**
     * @notice attribution manager
     */
    IRouxAdministrator internal immutable _administrator;

    /* -------------------------------------------- */
    /* structures                                   */
    /* -------------------------------------------- */

    /**
     * @notice RouxEdition storage
     * @custom:storage-location erc7201:rouxEdition.rouxEditionStorage
     *
     * @param initialized whether the contract has been initialized
     * @param tokenId current token id
     * @param tokens mapping of token id to token data
     */
    struct RouxEditionStorage {
        bool initialized;
        IRouxEditionFactory factory;
        uint256 tokenId;
        mapping(uint256 tokenId => TokenData tokenData) tokens;
    }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    constructor(address administrator) {
        // disable initialization of implementation contract
        _storage().initialized = true;

        // set attribution manager
        _administrator = IRouxAdministrator(administrator);
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    /**
     * @notice initialize RouxEdition
     * @param init initial token data
     *
     * @dev initToken encoded as follows:
     *      (string tokenUri, address creator, uint32 maxSupply, address fundsRecipient, uint16 profitShare, address
     *      parentEdition, uint256 parentTokenId, address minter, bytes options)
     *
     *      options params encoded as required by minter
     */
    function initialize(bytes calldata init) external {
        RouxEditionStorage storage $ = _storage();

        // initialize
        require(!$.initialized, "Already initialized");
        $.initialized = true;

        // set factory
        $.factory = IRouxEditionFactory(msg.sender);

        // factory transfers ownership to caller after initialization
        _initializeOwner(msg.sender);

        // add initial token if provided
        if (init.length > 0) {
            // decode token data
            (
                string memory tokenUri,
                address creator_,
                uint32 maxSupply,
                address fundsRecipient,
                uint16 profitShare,
                address parentEdition,
                uint256 parentTokenId,
                address minter,
                bytes memory options
            ) = abi.decode(init, (string, address, uint32, address, uint16, address, uint256, address, bytes));

            // add token
            _add(
                tokenUri,
                creator_,
                maxSupply,
                fundsRecipient,
                profitShare,
                parentEdition,
                parentTokenId,
                minter,
                options
            );
        }
    }

    /* -------------------------------------------- */
    /* storage                                      */
    /* -------------------------------------------- */

    /**
     * @notice get RouxEdition storage location
     * @return $ RouxEdition storage location
     */
    function _storage() internal pure returns (RouxEditionStorage storage $) {
        assembly {
            $.slot := ROUX_EDITION_STORAGE_SLOT
        }
    }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxEdition
     */
    function creator(uint256 id) external view returns (address) {
        return _storage().tokens[id].creator;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function currentToken() external view returns (uint256) {
        return _storage().tokenId;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function totalSupply(uint256 id) external view override returns (uint256) {
        return _storage().tokens[id].totalSupply;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function uri(uint256 id) public view override(IRouxEdition, ERC1155) returns (string memory) {
        return _storage().tokens[id].uri;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function attribution(uint256 id) external view returns (address, uint256) {
        (address parentEdition, uint256 parentTokenId) = _administrator.attribution(address(this), id);

        return (parentEdition, parentTokenId);
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function exists(uint256 id) external view returns (bool) {
        return _exists(id);
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxEdition
     */
    function mint(
        address to,
        uint256 id,
        uint256 quantity,
        bytes calldata /*  data */
    )
        external
        onlyRoles(MINTER_ROLE)
    {
        RouxEditionStorage storage $ = _storage();

        // verify token exists
        if (!_exists(id)) revert InvalidTokenId();

        // validate max supply
        if (quantity + $.tokens[id].totalSupply > $.tokens[id].maxSupply) revert MaxSupplyExceeded();

        // update total quantity
        _storage().tokens[id].totalSupply += quantity.toUint128();

        // mint
        _mint(to, id, quantity, "");
    }

    /* -------------------------------------------- */
    /* admin | onlyOwner                            */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxEdition
     */
    function add(
        string memory tokenUri,
        address creator_,
        uint256 maxSupply,
        address fundsRecipient,
        uint256 profitShare,
        address parentEdition,
        uint256 parentTokenId,
        address minter,
        bytes memory options
    )
        external
        onlyOwner
        returns (uint256)
    {
        return _add(
            tokenUri, creator_, maxSupply, fundsRecipient, profitShare, parentEdition, parentTokenId, minter, options
        );
    }

    /**
     * @notice update uri
     * @param id token id to update
     * @param newUri new uri
     */
    function updateUri(uint256 id, string memory newUri) external onlyOwner {
        _storage().tokens[id].uri = newUri;

        emit URI(newUri, id);
    }

    /**
     * @notice add minter
     * @param minter minter address
     */
    function addMinter(address minter) external onlyOwner {
        _addMinter(minter);
    }

    /**
     * @notice update mint params
     */
    function updateMintParams(uint256 id, address minter, bytes calldata params) external onlyOwner {
        // set sales params via minter
        _setMintParams(id, minter, params);
    }

    /* -------------------------------------------- */
    /* internal                                     */
    /* -------------------------------------------- */

    function _add(
        string memory tokenUri,
        address creator_,
        uint256 maxSupply,
        address fundsRecipient,
        uint256 profitShare,
        address parentEdition,
        uint256 parentTokenId,
        address minter,
        bytes memory options
    )
        internal
        returns (uint256)
    {
        RouxEditionStorage storage $ = _storage();

        // increment token id
        uint256 id = ++$.tokenId;

        // get storage pointer
        TokenData storage d = $.tokens[id];

        // set token data
        d.uri = tokenUri;
        d.creator = creator_;
        d.maxSupply = maxSupply.toUint128();

        // set administrator data via administrator
        _setAdministratorData(id, fundsRecipient, profitShare.toUint16(), parentEdition, parentTokenId);

        // optionally add minter
        if (minter != address(0)) _addMinter(minter);

        // set optional params in minter if provided
        if (options.length > 0) _setMintParams(id, minter, options);

        emit TokenAdded(id, parentEdition, parentTokenId);

        return id;
    }

    /**
     * @notice set administrator data
     * @param id token id
     * @param fundsRecipient funds recipient
     * @param profitShare profit share
     * @param parentEdition parent edition
     * @param parentTokenId parent token id
     *
     * @dev sets administrator data on the administrator
     */
    function _setAdministratorData(
        uint256 id,
        address fundsRecipient,
        uint16 profitShare,
        address parentEdition,
        uint256 parentTokenId
    )
        internal
    {
        // check if parent edition has been provided
        if (parentEdition != address(0)) {
            // revert if parent is the same contract, not an edition, or not a valid token
            if (
                !_storage().factory.isEdition(parentEdition) || !IRouxEdition(parentEdition).exists(parentTokenId)
                    || parentEdition == address(this)
            ) {
                revert InvalidAttribution();
            }
        }

        // set administrator data via administrator
        _administrator.setAdministratorData(id, fundsRecipient, profitShare, parentEdition, parentTokenId);
    }

    /**
     * @notice set mint params
     * @param id token id
     * @param options minter options
     */
    function _setMintParams(uint256 id, address minter, bytes memory options) internal {
        // set sales params via minter
        IEditionMinter(minter).setMintParams(id, options);
    }

    /**
     * @notice add minter
     * @param minter minter address
     */
    function _addMinter(address minter) internal {
        grantRoles(minter, MINTER_ROLE);

        emit MinterAdded(minter);
    }

    /**
     * @notice check if token exists
     * @param id token id
     */
    function _exists(uint256 id) internal view returns (bool) {
        return id != 0 && id <= _storage().tokenId;
    }
}
