//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SatoshiOpstion is ERC721, Ownable {
    // 筹码
    address public cppc;

    // 用户的 nft 列表
    // user => [ids]
    mapping(address => uint256[]) private _idBalance;

    struct NftData {
        address _address;
        string lever;
        string cppcNum;
        uint256 createTime;
        uint256 openPrice;
        string direction;
        bool isEnable;
    }

    constructor(
        address _cppc,
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {
        cppc = _cppc;
    }

    function setCppc(address _cppc) external onlyOwner {
        cppc = _cppc;
    }

    function balanceOfOwner(address _owner)
        external
        view
        returns (uint256[] memory ids)
    {
        uint256[] memory idAll = _idBalance[_owner];
        uint256 len = balanceOf(_owner);
        ids = new uint256[](len);
        uint256 index;
        for (uint256 i = 0; i < idAll.length; i++) {
            if (ownerOf(idAll[i]) == _owner) {
                ids[index] = idAll[i];
                index++;
            }
        }
    }

    // 记录 id
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        _idBalance[to].push(tokenId);
    }

    function create() public returns (uint256 tokenId) {
        
    }
}
