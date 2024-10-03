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
import { EventsLib } from "src/libraries/EventsLib.sol";
/**
 * @title roux mint portal
 * @author roux
 * @custom:version 1.0
 * @custom:security-contact mp@roux.app
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
    uint256 private constant PROMOTIONAL_MINTER_ROLE = 1;

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

        // set token restrictions
        setTokenRestriction(rUSDC_ID, true);
    }

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

        emit EventsLib.Deposit(to, rUSDC_ID, amount);
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
        if (cost > 0) _burn(msg.sender, rUSDC_ID, cost);

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
        if (cost > 0) _burn(msg.sender, rUSDC_ID, cost);

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
        if (cost > 0) _burn(msg.sender, rUSDC_ID, cost);

        // approve if necessary
        _manageApprovals(address(collection));

        // mint to caller
        collection.mint(msg.sender, extension, referrer, data);
    }

    /// @dev redeem free edition mint
    function redeemEditionMint(address edition, uint256 id, address referrer, bytes calldata data) external {
        // validate edition
        if (!_editionFactory.isEdition(address(edition))) revert RouxMintPortal_InvalidEdition();

        // mint to caller, passing this contract as the extension
        IRouxEdition(edition).mint(msg.sender, id, 1, address(this), referrer, data);

        emit EventsLib.EditionMintRedemption(msg.sender, edition, id);
    }

    /// @dev redeem free collection mint
    function redeemCollectionMint(address collection, address referrer, bytes calldata data) external {
        // validate collection
        if (!_collectionFactory.isCollection(address(collection))) revert RouxMintPortal_InvalidCollection();

        // mint to caller, passing this contract as the extension
        ICollection(collection).mint(msg.sender, address(this), referrer, data);

        emit EventsLib.CollectionMintRedemption(msg.sender, collection);
    }

    /// @inheritdoc IExtension
    function approveMint(
        uint256 id,
        uint256 quantity,
        address, /* operator */
        address account,
        bytes calldata /* data */
    )
        external
        returns (uint256)
    {
        if (_editionFactory.isEdition(msg.sender)) {
            // cannot mint gated tokens
            if (IRouxEdition(msg.sender).isGated(id)) revert ErrorsLib.RouxMintPortal_GatedMint();

            // burn free edition mint tokens
            _burn(account, FREE_EDITION_MINT_ID, quantity);

            return 0;
        }

        if (_collectionFactory.isCollection(address(msg.sender))) {
            // cannot mint gated tokens
            if (ICollection(msg.sender).isGated()) revert ErrorsLib.RouxMintPortal_GatedMint();

            // burn free collection mint tokens
            _burn(account, FREE_COLLECTION_MINT_ID, 1);

            return 0;
        }

        revert ErrorsLib.RouxMintPortal_InvalidCaller();
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

    /**
     * @notice mint free edition mint
     * @param to recipient
     * @param quantity quantity
     */
    function mintPromotionalTokens(
        address to,
        uint256 id,
        uint256 quantity
    )
        external
        onlyOwnerOrRoles(PROMOTIONAL_MINTER_ROLE)
    {
        if (id != FREE_EDITION_MINT_ID && id != FREE_COLLECTION_MINT_ID) revert ErrorsLib.RouxMintPortal_InvalidToken();

        _mint(to, id, quantity, "");
    }

    /**
     * @notice set token restriction
     * @param id token id
     * @param restricted whether the token is restricted
     */
    function setTokenRestriction(uint256 id, bool restricted) public virtual onlyOwner {
        _setTokenRestriction(id, restricted);

        emit EventsLib.TokenRestrictionSet(id, restricted);
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
        Restricted1155Storage storage $ = _restricted1155Storage();

        if (!$.approvals[contract_].get(uint256(uint160(contract_)))) {
            _underlying.safeApprove(contract_, type(uint256).max);
            $.approvals[contract_].set(uint256(uint160(contract_)));
        }
    }
}
