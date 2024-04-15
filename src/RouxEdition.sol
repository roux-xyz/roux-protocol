// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { ERC1155 } from "solady/tokens/ERC1155.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { IRouxAdministrator } from "src/interfaces/IRouxAdministrator.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract RouxEdition is IRouxEdition, ERC1155, OwnableRoles {
    using SafeCast for uint256;

    /* -------------------------------------------- */
    /* constants                                    */
    /* -------------------------------------------- */

    /**
     * @notice RouxEdition storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxEdition.rouxEditionStorage")) - 1)) & ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_CREATOR_STORAGE_SLOT =
        0xef2f5668c8b56b992983464f11901aec8635a37d61a520221ade259ca1a88200;

    /**
     * @notice implementation version
     */
    string public constant IMPLEMENTATION_VERSION = "1.0";

    /**
     * @notice basis point scale
     */
    uint256 internal constant BASIS_POINT_SCALE = 10_000;

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

    function initialize(bytes calldata params) external {
        RouxEditionStorage storage $ = _storage();

        // initialize
        require(!$.initialized, "Already initialized");
        $.initialized = true;

        // set factory
        $.factory = IRouxEditionFactory(msg.sender);

        // factory transfers ownership to caller after initialization
        _initializeOwner(msg.sender);

        // if params are provided, parse and set
        if (params.length > 0) {
            (
                TokenSaleData memory s,
                IRouxAdministrator.AdministratorData memory a,
                string memory tokenUri,
                address creator_
            ) = abi.decode(params, (TokenSaleData, IRouxAdministrator.AdministratorData, string, address));

            // add token
            _add(s, a, tokenUri, creator_);
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
            $.slot := ROUX_CREATOR_STORAGE_SLOT
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
    function implementationVersion() external pure returns (string memory) {
        return IMPLEMENTATION_VERSION;
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
    function price(uint256 id) external view returns (uint256) {
        return _storage().tokens[id].saleData.price;
    }

    /**
     * @inheritdoc IRouxEdition
     */
    function maxSupply(uint256 id) external view returns (uint256) {
        return _storage().tokens[id].saleData.maxSupply;
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
        return id != 0 && id <= _storage().tokenId;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxEdition
     */
    function mint(address to, uint256 id, uint256 quantity) external payable {
        // safe cast to uint32
        uint32 quantity_ = quantity.toUint32();

        // get storage
        RouxEditionStorage storage $ = _storage();

        // verify token id
        if (id == 0 || id > $.tokenId) revert InvalidTokenId();

        // verify mint is active
        if (block.timestamp < $.tokens[id].saleData.mintStart) revert MintNotStarted();
        if (block.timestamp > $.tokens[id].saleData.mintEnd) revert MintEnded();

        // verify quantity does not exceed max supply
        if (quantity_ + $.tokens[id].totalSupply > $.tokens[id].saleData.maxSupply) revert MaxSupplyExceeded();

        // verify quantity does not exceed max mintable by single address
        if (balanceOf(to, id) + quantity_ > $.tokens[id].saleData.maxMintable) revert MaxMintableExceeded();

        // verify sufficient funds
        if (msg.value < $.tokens[id].saleData.price * quantity) revert InsufficientFunds();

        // update total quantity
        $.tokens[id].totalSupply += quantity_;

        // mint
        _mint(to, id, quantity, "");

        // distribute funds via administrator
        _administrator.disburse{ value: msg.value }(id);
    }

    /* -------------------------------------------- */
    /* admin | onlyOwner                            */
    /* -------------------------------------------- */

    /**
     * @inheritdoc IRouxEdition
     */
    function add(
        TokenSaleData calldata tokenSaleData,
        IRouxAdministrator.AdministratorData calldata administratorData,
        string memory tokenUri,
        address creator_
    )
        external
        onlyOwner
        returns (uint256)
    {
        return _add(tokenSaleData, administratorData, tokenUri, creator_);
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

    /* -------------------------------------------- */
    /* internal                                     */
    /* -------------------------------------------- */

    function _add(
        TokenSaleData memory s,
        IRouxAdministrator.AdministratorData memory a,
        string memory tokenUri,
        address creator_
    )
        internal
        returns (uint256)
    {
        RouxEditionStorage storage $ = _storage();

        // if fork, price must be at least equal to that of parent
        if (a.parentEdition != address(0) && s.price < RouxEdition(a.parentEdition).price(a.parentTokenId)) {
            revert InvalidPrice();
        }

        // increment token id
        uint256 id = ++$.tokenId;

        // get storage pointer
        TokenData storage d = $.tokens[id];

        // set token sale data
        d.saleData = s;

        // set token data
        d.uri = tokenUri;
        d.creator = creator_;

        // set administrator data via administrator
        _setAdministratorData(id, a);

        emit TokenAdded(id, a.parentEdition, a.parentTokenId);

        return id;
    }

    /**
     * @notice set administrator data
     * @param tokenId token id
     * @param a administrator data
     *
     * @dev sets administrator data on the administrator
     */
    function _setAdministratorData(uint256 tokenId, IRouxAdministrator.AdministratorData memory a) internal {
        // check if parent edition has been provided
        if (a.parentEdition != address(0)) {
            // revert if parent is the same contract, not an edition, or not a valid token
            if (
                !_storage().factory.isEdition(a.parentEdition) || !IRouxEdition(a.parentEdition).exists(a.parentTokenId)
                    || a.parentEdition == address(this)
            ) {
                revert InvalidAttribution();
            }
        }

        // set administrator data via administrator
        _administrator.setAdministratorData(tokenId, a);
    }
}
