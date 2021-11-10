// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MinterAccess is AccessControl, Ownable {

    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() {
        address owner = _msgSender();
        super._setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        super._setupRole(MINTER_ROLE, owner);
        super._setupRole(DEFAULT_ADMIN_ROLE, owner);
    }

    function hasMinterRole(address account) public view returns(bool) {
        return super.hasRole(MINTER_ROLE, account);
    }

    function setupMinterRole(address account) public onlyOwner {
        super._setupRole(MINTER_ROLE, account);
    }

    function revokeMinterRole(address account) public onlyOwner {
        super.revokeRole(MINTER_ROLE, account);
    }

    modifier onlyMinter() {
        require(hasMinterRole(_msgSender()), "MinterAccess: sender do not have the minter role");
        _;
    }
}

contract Cppc is ERC20("Cppc", "Cppc"), MinterAccess {

    function mint(address _to, uint256 _amount) external onlyMinter {
        super._mint(_to, _amount);
    }

    function burn( uint256 _amount) external {
        super._burn(_msgSender(), _amount);
    }

}

