// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { IERC6551Account } from "erc6551/interfaces/IERC6551Account.sol";
import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { IERC6551Executable } from "erc6551/interfaces/IERC6551Executable.sol";

import { ERC6551AccountLib } from "erc6551/lib/ERC6551AccountLib.sol";

contract ERC6551Account is IERC165, ERC721Holder, ERC1155Holder, IERC6551Account {
    /* ------------------------------------------------ */
    /* errors                                           */
    /* ------------------------------------------------ */
    error InvalidSigner();

    error OnlyCallOperations();

    /* ------------------------------------------------ */
    /* structures                                       */
    /* ------------------------------------------------ */

    enum Operation {
        Call,
        DelegateCall,
        Create,
        Create2
    }

    /* ------------------------------------------------ */
    /* immutable                                        */
    /* ------------------------------------------------ */

    IERC6551Registry internal immutable _erc6551Registry;

    /* ------------------------------------------------ */
    /* state                                            */
    /* ------------------------------------------------ */

    bool internal _initialized;

    uint256 internal _state;

    /* ------------------------------------------------ */
    /* constructor                                      */
    /* ------------------------------------------------ */

    constructor(address erc6551Registry) {
        /* disable initialization of implementation contract */
        _initialized = true;

        _erc6551Registry = IERC6551Registry(erc6551Registry);
    }

    /* ------------------------------------------------ */
    /* initializer                                      */
    /* ------------------------------------------------ */

    function initialize() external {
        require(!_initialized, "already initialized");
        _initialized = true;
    }

    /* ------------------------------------------------ */
    /* receive                                          */
    /* ------------------------------------------------ */

    receive() external payable virtual { }

    /* ------------------------------------------------ */
    /* view                                             */
    /* ------------------------------------------------ */

    function token() external view returns (uint256, address, uint256) {
        return ERC6551AccountLib.token();
    }

    function state() external view returns (uint256) {
        return _state;
    }

    function owner() external view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = ERC6551AccountLib.token();
        return _owner(chainId, tokenContract, tokenId);
    }

    function isValidSigner(address signer, bytes calldata) external view returns (bytes4) {
        if (_isValidSigner(signer)) {
            return IERC6551Account.isValidSigner.selector;
        }

        return bytes4(0);
    }

    /* ------------------------------------------------ */
    /* write                                            */
    /* ------------------------------------------------ */

    function execute(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation
    )
        external
        payable
        virtual
        returns (bytes memory result)
    {
        if (!_isValidSigner(msg.sender)) revert InvalidSigner();
        if (operation != Operation.Call) revert OnlyCallOperations();

        _updateState();

        bool success;
        (success, result) = to.call{ value: value }(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /* ------------------------------------------------ */
    /* internal                                         */
    /* ------------------------------------------------ */

    function _updateState() internal {
        _state = uint256(keccak256(abi.encode(_state, msg.data)));
    }

    function _owner(uint256 chainId, address tokenContract, uint256 tokenId) internal view returns (address) {
        if (chainId != block.chainid) return address(0);
        if (tokenContract.code.length == 0) return address(0);

        try IERC721(tokenContract).ownerOf(tokenId) returns (address owner_) {
            return owner_;
        } catch {
            return address(0);
        }
    }

    function _isValidSigner(address signer) internal view returns (bool) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = ERC6551AccountLib.token();
        address owner_ = _owner(chainId, tokenContract, tokenId);

        return signer == owner_;
    }

    /* ------------------------------------------------ */
    /* supports interface                               */
    /* ------------------------------------------------ */

    function supportsInterface(bytes4 interfaceId) public pure override(ERC1155Holder, IERC165) returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC6551Account).interfaceId
            || interfaceId == type(IERC6551Executable).interfaceId;
    }
}
