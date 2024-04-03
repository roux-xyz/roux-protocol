// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IRouxCreatorFactory {
    /* -------------------------------------------- */
    /* errors                                       */
    /* -------------------------------------------- */

    error OnlyAllowlist();

    /* -------------------------------------------- */
    /* events                                       */
    /* -------------------------------------------- */

    event NewCreator(address indexed instance);

    /* -------------------------------------------- */
    /* view functions                               */
    /* -------------------------------------------- */

    function isCreator(address token) external view returns (bool);

    function getCreators() external view returns (address[] memory);
}
