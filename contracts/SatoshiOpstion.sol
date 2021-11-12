//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";

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
    uint256 depositFee = 3000; // 0.3 * 10000;
    // 平仓费率
    uint256 withdrawFee = 3000; // 0.3 * 10000;

    uint256 sigma = 10000; //1 * 10000; 大写Σ，小写σ
    uint256 lambda = 509686; // 50.9686 * 10000;
    uint256 eta1 = 215100; //21.51 * 10000; η1
    uint256 eta2 = 241500; //24.15 * 10000; η2
    uint256 _p = 5645; //0.5645 * 10000;
    uint256 _q = 4355; //0.4355 * 10000;

    struct L1Item {
        uint256 L1;
        uint256 delta; //10**10
        uint256 L2; //10**10
    }
    mapping(uint256 => L1Item) private _l1Table;

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
        uint256 _depositFee,
        uint256 _withdrawFee
    ) public onlyOwner {
        upBtc = _upBtc;
        downBtc = _downBtc;
        depositFee = _depositFee;
        withdrawFee = _withdrawFee;
    }

    /**
    配置L表格
    */
    function SetLTable(L1Item[] calldata _l1Item) external onlyOwner {
        uint256 length = _l1Item.length;
        require(length > 0);
        for (uint256 i = 0; i < length; i++) {
            L1Item memory l1Item = _l1Item[i];
            uint256 _l1 = l1Item.L1;
            _l1Table[_l1] = l1Item;
        }
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

    // 获取Omg值
    function getOmg(uint256 l1, uint256 l2) private view returns (int128) {
        int128 _eta1_128 = ABDKMath64x64.fromUInt(eta1);
        int128 _l1_128 = ABDKMath64x64.fromUInt(l1);
        int128 _l2_128 = ABDKMath64x64.fromUInt(l2);
        int128 _a = ABDKMath64x64.sub(_eta1_128, _l1_128);
        int128 _b = _eta1_128;
        int128 _a1 = _l2_128;
        int128 _b1 = ABDKMath64x64.sub(_l2_128, _l1_128);
        int128 _omg = ABDKMath64x64.mul(
            ABDKMath64x64.div(_a, _b),
            ABDKMath64x64.div(_a1, _b1)
        );
        return _omg;
    }

    // 获取开仓算数量
    function getPurchaseQuantity(
        int128 bk,
        uint256 l1,
        uint256 l2,
        uint256
    ) private view returns (int128) {
        int128 omg = getOmg(l1, l2);
        int128 bkPowL1 = ABDKMath64x64.pow(bk, l1);
        int128 bkPowL2 = ABDKMath64x64.pow(bk, l2);
        int128 omg1 = ABDKMath64x64.mul(omg, bkPowL1);
        int128 omg2 = ABDKMath64x64.mul(ABDKMath64x64.sub(1, omg), bkPowL2);
        int128 pbc = ABDKMath64x64.add(omg1, omg2);
        return pbc;
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

    // function

    // 记录 id
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        _idBalance[to].push(tokenId);
    }
}
