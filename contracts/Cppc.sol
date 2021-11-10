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

    function hasMinterRole(address account) public view returns (bool) {
        return super.hasRole(MINTER_ROLE, account);
    }

    function setupMinterRole(address account) public onlyOwner {
        super._setupRole(MINTER_ROLE, account);
    }

    function revokeMinterRole(address account) public onlyOwner {
        super.revokeRole(MINTER_ROLE, account);
    }

    modifier onlyMinter() {
        require(
            hasMinterRole(_msgSender()),
            "MinterAccess: sender do not have the minter role"
        );
        _;
    }
}

contract Cppc is ERC20("Cppc", "Cppc"), MinterAccess {
    uint256 upBtc = 0;
    uint256 downBtc = 0;
    string depositFee = "0.3";
    string withdrawFee = "0.3";
    struct CppcData {
        address _address;
        address _nftAddress;
        string lever;
        string cppcNum;
        uint256 createTime;
        uint256 openPrice;
        string direction;
        bool isEnable;
    }
    mapping(address => CppcData) cppcStore;
    address payable[] cppcAddress;

    function mint(address _to, uint256 _amount) external onlyMinter {
        super._mint(_to, _amount);
    }

    function burn(uint256 _amount) external {
        super._burn(_msgSender(), _amount);
    }

    function SetConfig(
        uint256 _upBtc,
        uint256 _downBtc,
        string memory _depositFee,
        string memory _withdrawFee
    ) public onlyOwner {
        upBtc = _upBtc;
        downBtc = _downBtc;
        depositFee = _depositFee;
        withdrawFee = _withdrawFee;
    }

    modifier isCppcAddress() {
        CppcData storage cppcData = cppcStore[msg.sender];
        if (cppcData.isEnable) {
            _;
        }
    }

    function getCppcInfo() external view returns (CppcData memory) {
        CppcData storage cppcData = cppcStore[msg.sender];
        return cppcData;
    }

    function Deposit(
        string memory lever,
        string memory amount,
        uint256 btcPrice,
        string memory _type
    ) public payable returns (uint256) {
        address nftAddress = msg.sender; //TODO NFT id
        CppcData storage cppcData = cppcStore[msg.sender];
        cppcData._address = msg.sender;
        cppcData._nftAddress = nftAddress;
        cppcData.lever = lever;
        cppcData.cppcNum = amount;
        cppcData.createTime = block.timestamp;
        cppcData.openPrice = btcPrice;
        cppcData.direction = _type;
        cppcData.isEnable = true;

        cppcAddress.push(payable(msg.sender));
        //TODO getCPPCNum
        return 0;
    }

    function Withdraw(uint256 btcPrice) public isCppcAddress {
        CppcData memory cppcData = this.getCppcInfo();
        
    }
}
