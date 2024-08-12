// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IRouxMintPortal } from "src/interfaces/IRouxMintPortal.sol";
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

/**
 * @title roux mint portal
 * @author roux
 * @custom:version 1.0
 * @custom:security-contact mp@roux.app
 */
contract RouxMintPortal is IRouxMintPortal, Restricted1155, Initializable, OwnableRoles, ReentrancyGuard {
    using SafeTransferLib for address;

    /* -------------------------------------------- */
    /* immutable state                              */
    /* -------------------------------------------- */

    /// @notice underlying token
    address internal immutable _underlying;

    /// @notice edition factory
    IRouxEditionFactory internal immutable _editionFactory;

    /// @notice collection factory
    ICollectionFactory internal immutable _collectionFactory;

    /// @notice token id
    uint256 private constant rUSDC_ID = 1;

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
        uint256 cost = edition.defaultPrice(id) * quantity;

        // burn rUSDC
        _burn(msg.sender, rUSDC_ID, cost);

        // approve edition
        _underlying.safeApprove(address(edition), cost);

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
            cost += edition.defaultPrice(ids[i]) * quantities[i];
        }

        // burn rUSDC
        _burn(msg.sender, rUSDC_ID, cost);

        // approve edition
        _underlying.safeApprove(address(edition), cost);

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
        uint256 cost = collection.price();

        // burn rUSDC
        _burn(msg.sender, rUSDC_ID, cost);

        // approve collection
        _underlying.safeApprove(address(collection), cost);

        // mint to caller
        collection.mint(msg.sender, extension, referrer, data);
    }

    /// TODO: add uri
    function uri(uint256) public pure override returns (string memory) {
        return "https://api.roux.art/token/rUSDC";
    }

    /* -------------------------------------------- */
    /* admin                                        */
    /* -------------------------------------------- */

    /**
     * @notice rescue underlying token
     * @param to address to send underlying token to
     * @dev underlying token balance and total supply should always be equal, unless underlying token
     *      is accidentally sent to this contract instead of calling `deposit`
     */
    function rescue(address to) external onlyOwner {
        uint256 amount = IERC20(_underlying).balanceOf(address(this)) - _restricted1155Storage().totalSupply;

        // transfer underlying token from caller to this contract
        _underlying.safeTransfer(to, amount);
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
}
