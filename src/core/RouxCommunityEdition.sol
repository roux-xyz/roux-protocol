// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { BaseRouxEdition } from "src/core/abstracts/BaseRouxEdition.sol";
import { IRouxEdition } from "src/core/interfaces/IRouxEdition.sol";
import { EditionData } from "src/types/DataTypes.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { ErrorsLib } from "src/libraries/ErrorsLib.sol";
import { EventsLib } from "src/libraries/EventsLib.sol";

/**
 * italian heirloom
 *
 * 2 oz cynar
 * 1/2 oz blended scotch
 * 1/2 oz laphroaig 10 yr
 * pinch salt
 * 5 swaths of lemon peel
 *
 * build in mixing glass, expressing lemon peels and dropping them
 * into the glass
 *
 * stir and strain, served up
 *
 * garnish with lemon peel
 */

/**
 * @title roux edition community
 * @author roux
 * @custom:security-contact security@roux.app
 *
 * @dev roux community edition is a special edition type that does not enforce an `onlyOwner` modifier
 * on `add`. an allowlist can be optionally enabled and set for group co-creation.
 */
contract RouxCommunityEdition is BaseRouxEdition {
    using LibBitmap for LibBitmap.Bitmap;

    /* ------------------------------------------------- */
    /* constants                                         */
    /* ------------------------------------------------- */

    /**
     * @notice RouxCommunityEdition storage slot
     * @dev keccak256(abi.encode(uint256(keccak256("rouxCommunityEdition.rouxCommunityEditionStorage")) - 1)) &
     * ~bytes32(uint256(0xff));
     */
    bytes32 internal constant ROUX_COMMUNITY_EDITION_STORAGE_SLOT =
        0x856d5c392d13026bc2723f4319adbd96ce80b3e18403d4874ff5a642b699de00;

    /* ------------------------------------------------- */
    /* structures                                     */
    /* ------------------------------------------------- */

    /**
     * @notice RouxCommunityEdition storage
     * @custom:storage-location erc7201:rouxCommunityEdition.rouxCommunityEditionStorage
     * @param addWindowStart add window start
     * @param addWindowEnd add window end
     * @param maxAddsPerAddress max adds per address
     * @param addsPerAddress adds per address
     * @param allowListEnabled allowlist enabled
     * @param allowedAddresses allowed addresses
     */
    struct RouxCommunityEditionStorage {
        uint40 addWindowStart;
        uint40 addWindowEnd;
        uint32 maxAddsPerAddress;
        mapping(address => uint32) addsPerAddress;
        bool allowListEnabled;
        LibBitmap.Bitmap allowedAddresses;
    }

    /* ------------------------------------------------- */
    /* constructor                                       */
    /* ------------------------------------------------- */

    /**
     * @notice constructor
     * @param editionFactory edition factory
     * @param collectionFactory collection factory
     * @param controller controller
     * @param registry registry
     */
    constructor(
        address editionFactory,
        address collectionFactory,
        address controller,
        address registry
    )
        BaseRouxEdition(editionFactory, collectionFactory, controller, registry)
    { }

    /* ------------------------------------------------- */
    /* initializer                                       */
    /* ------------------------------------------------- */

    /**
     * @notice initialize RouxCommunityEdition
     * @param params encoded parameters
     */
    function initialize(bytes calldata params) external override initializer {
        // call parent initialize first
        _initialize(params);

        // get storage
        RouxCommunityEditionStorage storage $$ = _storageCommunity();

        // set default values
        $$.addWindowStart = uint40(block.timestamp);
        $$.addWindowEnd = uint40(block.timestamp + 14 days);
        $$.maxAddsPerAddress = 1;
    }

    /* ------------------------------------------------- */
    /* storage                                           */
    /* ------------------------------------------------- */

    /**
     * @notice get RouxCommunityEdition storage location
     * @return $ RouxCommunityEdition storage location
     */
    function _storageCommunity() internal pure returns (RouxCommunityEditionStorage storage $) {
        assembly {
            $.slot := ROUX_COMMUNITY_EDITION_STORAGE_SLOT
        }
    }

    /* ------------------------------------------------- */
    /* view                                              */
    /* ------------------------------------------------- */

    /// @inheritdoc IRouxEdition
    function editionType() external pure override returns (EditionData.EditionType) {
        return EditionData.EditionType.Community;
    }

    /**
     * @notice is allowlist enabled
     * @return allowlist enabled
     */
    function isAllowlistEnabled() external view returns (bool) {
        return _storageCommunity().allowListEnabled;
    }

    /**
     * @notice is allowlisted
     * @param account account
     * @return allowlisted
     */
    function isAllowlisted(address account) external view returns (bool) {
        RouxCommunityEditionStorage storage $$ = _storageCommunity();
        return !$$.allowListEnabled || $$.allowedAddresses.get(uint256(uint160(account)));
    }

    /**
     * @notice get add window
     * @return add window start
     * @return add window end
     */
    function addWindow() external view returns (uint40, uint40) {
        RouxCommunityEditionStorage storage $$ = _storageCommunity();
        return ($$.addWindowStart, $$.addWindowEnd);
    }

    /**
     * @notice get max adds per address
     * @return max adds per address
     */
    function maxAddsPerAddress() external view returns (uint32) {
        return _storageCommunity().maxAddsPerAddress;
    }

    /**
     * @notice get adds per address
     * @param account account
     * @return adds per address
     */
    function getAddsPerAddress(address account) external view returns (uint32) {
        return _storageCommunity().addsPerAddress[account];
    }

    /* ------------------------------------------------- */
    /* write                                             */
    /* ------------------------------------------------- */

    /// @inheritdoc IRouxEdition
    function add(EditionData.AddParams calldata p) external override nonReentrant returns (uint256) {
        RouxCommunityEditionStorage storage $$ = _storageCommunity();

        // check add window
        if (block.timestamp < $$.addWindowStart || block.timestamp > $$.addWindowEnd) {
            revert ErrorsLib.RouxCommunityEdition_AddWindowClosed();
        }

        // check allowlist
        if ($$.allowListEnabled && !$$.allowedAddresses.get(uint256(uint160(msg.sender)))) {
            revert ErrorsLib.RouxCommunityEdition_NotAllowed();
        }

        // check max adds per address
        if ($$.addsPerAddress[msg.sender] >= $$.maxAddsPerAddress) {
            revert ErrorsLib.RouxCommunityEdition_MaxAddsPerAddressReached();
        }

        // update adds per address
        $$.addsPerAddress[msg.sender]++;

        return _add(p);
    }

    /* ------------------------------------------------- */
    /* admin                                             */
    /* ------------------------------------------------- */

    /**
     * @notice enable allowlist
     * @param enable enable
     */
    function enableAllowlist(bool enable) external onlyOwner {
        _storageCommunity().allowListEnabled = enable;

        emit EventsLib.CommunityAllowlistEnabled(enable);
    }

    /**
     * @notice add to allowlist
     * @param addresses addresses
     */
    function addToAllowlist(address[] calldata addresses) external onlyOwner {
        RouxCommunityEditionStorage storage $$ = _storageCommunity();
        for (uint256 i = 0; i < addresses.length; ++i) {
            $$.allowedAddresses.set(uint256(uint160(addresses[i])));
        }
    }

    /**
     * @notice remove from allowlist
     * @param account account
     */
    function removeFromAllowlist(address account) external onlyOwner {
        _storageCommunity().allowedAddresses.unset(uint256(uint160(account)));
    }

    /**
     * @notice update add window
     * @param addWindowStart add window start
     * @param addWindowEnd add window end
     */
    function updateAddWindow(uint40 addWindowStart, uint40 addWindowEnd) external onlyOwner {
        RouxCommunityEditionStorage storage $$ = _storageCommunity();
        if (addWindowStart >= addWindowEnd) {
            revert ErrorsLib.RouxCommunityEdition_InvalidAddWindow();
        }

        $$.addWindowStart = addWindowStart;
        $$.addWindowEnd = addWindowEnd;
    }

    /**
     * @notice update max adds per address
     * @param maxAddsPerAddress_ max adds per address
     */
    function updateMaxAddsPerAddress(uint32 maxAddsPerAddress_) external onlyOwner {
        _storageCommunity().maxAddsPerAddress = maxAddsPerAddress_;
    }

    /// @dev collections not allowed for community editions
    function setCollection(address, bool) external view override onlyOwner {
        revert ErrorsLib.RouxCommunityEdition_NotAllowed();
    }
}
