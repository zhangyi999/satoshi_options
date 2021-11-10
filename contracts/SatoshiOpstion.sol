//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SatoshiOpstion is ERC721, Ownable {
    // 筹码
    address public cppc;

    // 仓位id
    uint256 private _totalSupply;
    // 多单BTC价格
    uint256 upBtc = 0;
    // 空单BTC价格
    uint256 downBtc = 0;
    // 开仓费率
    string depositFee = "0.3";
    // 平仓费率
    string withdrawFee = "0.3";

    // 用户的 nft 列表
    // user => [ids]
    mapping(address => uint256[]) private _idBalance;

    struct NftData {
        address _address;
        uint256 pid;
        string lever;
        string cppcNum;
        uint256 createTime;
        uint256 openPrice;
        string direction;
        bool isEnable;
    }
    mapping(uint256 => NftData) private nftStore;

    constructor(
        address _cppc,
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {
        cppc = _cppc;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function setCppc(address _cppc) external onlyOwner {
        cppc = _cppc;
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

    modifier isCppcAddress(uint256 _pid) {
        NftData storage nftData = nftStore[_pid];
        if (nftData.isEnable) {
            _;
        }
    }

    function getCppcInfo(uint256 _pid) external view returns (NftData memory) {
        NftData storage cppcData = nftStore[_pid];
        return cppcData;
    }

    function getNFT() external view returns (NftData[] memory) {
        uint256[] memory pids = _idBalance[_msgSender()];
        uint256 length = pids.length;
        NftData[] memory NftDatas = new NftData[](length);
        if (length > 0) {
            for (uint256 id = 0; id < length; ++id) {
                NftData memory _Data = this.getCppcInfo(pids[id]);
                NftDatas[id] = _Data;
            }
        }
        return NftDatas;
    }

    // 开仓
    function open(NftData memory _nftData) public returns (uint256 pid) {
        pid = _mintNft(_msgSender());
        NftData storage nftData = nftStore[pid];
        nftData._address = _nftData._address;
        nftData.pid = pid;
        nftData.lever = _nftData.lever;
        nftData.cppcNum = _nftData.cppcNum;
        nftData.createTime = _nftData.createTime;
        nftData.openPrice = _nftData.openPrice;
        nftData.direction = _nftData.direction;
        nftData.isEnable = true;
        return pid;
    }

    function _mintNft(address _to) internal returns (uint256) {
        _mint(_to, _totalSupply);
        return _totalSupply += 1;
    }

    // 平仓
    function Withdraw(uint256 _pid, uint256 btcPrice)
        public
        view
        isCppcAddress(_pid)
    {
        NftData memory nftData = this.getCppcInfo(_pid);
        nftData.isEnable = false;
    }

    // 记录 id
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        _idBalance[to].push(tokenId);
    }
}
