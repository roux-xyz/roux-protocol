// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IRouxMintPortal } from "src/interfaces/IRouxMintPortal.sol";
import { IExtension } from "src/interfaces/IExtension.sol";
import { Restricted1155 } from "src/abstracts/Restricted1155.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { IRouxEdition } from "src/interfaces/IRouxEdition.sol";
import { ICollection } from "src/interfaces/ICollection.sol";
import { IRouxEditionFactory } from "src/interfaces/IRouxEditionFactory.sol";
import { ICollectionFactory } from "src/interfaces/ICollectionFactory.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";

/**
 * @title roux mint portal
 * @author roux
 * @custom:version 1.0
 * @custom:security-contact mp@roux.app
 *
 * @dev todo: make this extension -> pass itself through to edition
 */
contract RouxMintPortal is
    IRouxMintPortal,
    ERC165,
    Restricted1155,
    Initializable,
    OwnableRoles,
    ReentrancyGuard,
    IExtension
{
    using SafeTransferLib for address;
    using LibBitmap for LibBitmap.Bitmap;

    /* ------------------------------------------------- */
    /* constants                                         */
    /* ------------------------------------------------- */

    /**
     * @notice RouxMintPortal storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxMintPortal.rouxMintPortalStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_MINT_PORTAL_STORAGE_SLOT =
        0xba493600e1637ee3eb35d600336ab655f0ccd7614561e3120319798e27071400;

    /* -------------------------------------------- */
    /* immutable state                              */
    /* -------------------------------------------- */

    /// @notice underlying token
    address internal immutable _underlying;

    /// @notice edition factory
    IRouxEditionFactory internal immutable _editionFactory;

    /// @notice collection factory
    ICollectionFactory internal immutable _collectionFactory;

    /// @notice token ids
    uint256 private constant rUSDC_ID = 1;
    uint256 private constant FREE_EDITION_MINT_ID = 2;
    uint256 private constant FREE_COLLECTION_MINT_ID = 3;

    /// @notice roles
    uint256 private constant FREE_MINT_ROLE = 1;

    /* ------------------------------------------------- */
    /* structures                                        */
    /* ------------------------------------------------- */

    // /**
    //  * @notice RouxMintPortal storage
    //  * @custom:storage-location erc7201:rouxMintPortal.rouxMintPortalStorages
    //  */
    // struct RouxMintPortalStorage { }

    /* -------------------------------------------- */
    /* constructor                                  */
    /* -------------------------------------------- */

    /**
     * @notice constructor
     * @param underlying_ underlying token ~ must be stablecoin
     * @param editionFactory_  edition factory
     * @param collectionFactory_  collection factory
     */
    constructor(address underlying_, address editionFactory_, address collectionFactory_) {
        // disable initialization of implementation contract
        _disableInitializers();

        _underlying = underlying_;
        _editionFactory = IRouxEditionFactory(editionFactory_);
        _collectionFactory = ICollectionFactory(collectionFactory_);

        _initializeOwner(msg.sender);
        renounceOwnership();
    }

    /* -------------------------------------------- */
    /* initializer                                  */
    /* -------------------------------------------- */

    /// @notice initialize
    function initialize() external initializer {
        // set owner of proxy
        _initializeOwner(msg.sender);
    }

    /* ------------------------------------------------- */
    /* storage                                           */
    /* ------------------------------------------------- */

    // /**
    //  * @notice get RouxEdition storage location
    //  * @return $ RouxEdition storage location
    //  */
    // function _storage() internal pure returns (RouxMintPortalStorage storage $) {
    //     assembly {
    //         $.slot := ROUX_MINT_PORTAL_STORAGE_SLOT
    //     }
    // }

    /* -------------------------------------------- */
    /* view                                         */
    /* -------------------------------------------- */

    /**
     * @notice get the total supply of tokens
     * @return total supply of tokens
     */
    function totalSupply() external view returns (uint256) {
        return _restricted1155Storage().totalSupply[rUSDC_ID];
    }

    /// @inheritdoc IExtension
    function price(address, uint256) external pure returns (uint128) {
        return 0;
    }

    /// @dev see {ERC1155-uri}
    function uri(uint256) public view override returns (string memory) {
        // todo return proper uri
        return _restricted1155Storage().baseUri;
    }

    /* -------------------------------------------- */
    /* write                                        */
    /* -------------------------------------------- */

    /// @inheritdoc IRouxMintPortal
    function deposit(address to, uint256 amount) external nonReentrant {
        _deposit(to, rUSDC_ID, amount);
    }

    /// @inheritdoc IRouxMintPortal
    function mintEdition(
        IRouxEdition edition,
        uint256 id,
        uint256 quantity,
        address extension,
        address referrer,
        bytes calldata data
    )
        external
        nonReentrant
    {
        // validate edition
        if (!_editionFactory.isEdition(address(edition))) revert RouxMintPortal_InvalidEdition();

        // compute cost
        // @dev extension gets called twice in this flow, here and in edition
        uint256 cost;
        if (extension != address(0)) {
            cost = IExtension(extension).price(address(edition), id) * quantity;
        } else {
            cost = edition.defaultPrice(id) * quantity;
        }

        // burn rUSDC
        _burn(msg.sender, rUSDC_ID, cost);

        // approve edition
        _manageApprovals(address(edition));

        // mint to caller
        edition.mint(msg.sender, id, quantity, extension, referrer, data);
    }

    /// @inheritdoc IRouxMintPortal
    function batchMintEdition(
        IRouxEdition edition,
        uint256[] calldata ids,
        uint256[] calldata quantities,
        address[] calldata extensions,
        address referrer,
        bytes calldata data
    )
        external
        nonReentrant
    {
        // validate edition
        if (!_editionFactory.isEdition(address(edition))) revert RouxMintPortal_InvalidEdition();

        // compute cost
        uint256 cost;
        for (uint256 i = 0; i < ids.length; ++i) {
            if (extensions[i] != address(0)) {
                cost += IExtension(extensions[i]).price(address(edition), ids[i]) * quantities[i];
            } else {
                cost += edition.defaultPrice(ids[i]) * quantities[i];
            }
        }

        // burn rUSDC
        _burn(msg.sender, rUSDC_ID, cost);

        // approve edition
        _manageApprovals(address(edition));

        // mint to caller
        edition.batchMint(msg.sender, ids, quantities, extensions, referrer, data);
    }

    /// @inheritdoc IRouxMintPortal
    function mintCollection(
        ICollection collection,
        address extension,
        address referrer,
        bytes calldata data
    )
        external
        nonReentrant
    {
        // validate collection
        if (!_collectionFactory.isCollection(address(collection))) revert RouxMintPortal_InvalidCollection();

        // get cost
        uint256 cost;
        if (extension != address(0)) {
            cost = IExtension(extension).price(address(collection), 0);
        } else {
            cost = collection.price();
        }

        // burn rUSDC
        _burn(msg.sender, rUSDC_ID, cost);

        // approve if necessary
        _manageApprovals(address(collection));

        // mint to caller
        collection.mint(msg.sender, extension, referrer, data);
    }

    /// @dev redeem free edition mint
    function redeemEditionMint(address to, uint256 id, bytes calldata /* data */ ) external {
        // mint to caller
        IRouxEdition(msg.sender).mint({
            to: to,
            id: id,
            quantity: 1,
            extension: address(this),
            referrer: msg.sender,
            data: ""
        });
    }

    /// @inheritdoc IExtension
    function approveMint(
        uint256, /* id */
        uint256 quantity,
        address, /* operator */
        address account,
        bytes calldata /* data */
    )
        external
        returns (uint256)
    {
        // validate caller
        if (!_editionFactory.isEdition(msg.sender) && !_collectionFactory.isCollection(address(msg.sender))) {
            revert ErrorsLib.RouxMintPortal_InvalidCaller();
        }

        if (_editionFactory.isEdition(msg.sender)) {
            // burn free edition mint tokens
            _burn(account, FREE_EDITION_MINT_ID, quantity);
        }

        if (_collectionFactory.isCollection(address(msg.sender))) {
            // burn free collection mint tokens
            _burn(account, FREE_COLLECTION_MINT_ID, 1);
        }

        return 0;
    }

    /// @inheritdoc IExtension
    function setMintParams(uint256, /* id */ bytes calldata /* params */ ) external pure {
        revert ErrorsLib.RouxMintPortal_InvalidParams();
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    /**
     * @notice rescue underlying token
     * @param to address to send underlying token to
     *
     * @dev underlying token balance and total supply should always be equal, unless underlying token
     *      is accidentally sent to this contract instead of calling `deposit`
     */
    function rescue(address to) external onlyOwner {
        uint256 amount = IERC20(_underlying).balanceOf(address(this)) - _restricted1155Storage().totalSupply[rUSDC_ID];

        // transfer underlying token from caller to this contract
        _underlying.safeTransfer(to, amount);
    }

    /**
     * @notice set uri
     * @param newUri new uri
     */
    function setUri(string memory newUri) external onlyOwner {
        _restricted1155Storage().baseUri = newUri;

        emit URI(newUri, 1);
    }

    /* -------------------------------------------- */
    /* interface                                    */
    /* -------------------------------------------- */

    /// @inheritdoc IExtension
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IExtension, ERC165, Restricted1155)
        returns (bool)
    {
        return interfaceId == type(IExtension).interfaceId || super.supportsInterface(interfaceId);
    }

    /* -------------------------------------------- */
    /* internal                                     */
    /* -------------------------------------------- */

    /**
     * @notice deposit underlying token and mint rUSDC
     * @param to beneficiary
     * @param id token id
     * @param amount amount
     */
    function _deposit(address to, uint256 id, uint256 amount) internal {
        // transfer underlying token from caller to this contract
        _underlying.safeTransferFrom(msg.sender, address(this), amount);

        // mint rUSDC to recipient
        _mint(to, id, amount, "");
    }

    /**
     * @notice manage approvals
     * @param contract_ contract address
     *
     * @dev if the contract has not been approved, approve the max for known contracts,
     *      otherwise we can skip the unnecessary external call
     */
    function _manageApprovals(address contract_) internal {
        Restricted1155Storage storage $$ = _restricted1155Storage();

        if (!$$.approvals[contract_].get(uint256(uint160(contract_)))) {
            _underlying.safeApprove(contract_, type(uint256).max);
            $$.approvals[contract_].set(uint256(uint160(contract_)));
        }
    }
}
