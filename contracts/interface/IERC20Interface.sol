// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Interface {
    function balanceOf(address user) external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;

    function issue(address account, uint amount) external;
    function burn(address account, uint amount) external returns(bool);
}