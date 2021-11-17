//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";

contract SatoshiOpstion is ERC721, Ownable {
    // 筹码
    address public cppc;

    // 仓位id
    uint256 private _totalSupply;
    // 多单BTC价格
    int128 upBtc = 0;
    // 空单BTC价格
    int128 downBtc = 0;
    // 开仓费率
    int128 depositFee = 3000; // 0.3 * 10000;
    // 平仓费率
    int128 withdrawFee = 3000; // 0.3 * 10000;

    int128 sigma = 10000; //1 * 10000; 大写Σ，小写σ
    // sigma = 2**64
    int128 lambda = 509686; // 50.9686 * 10000; λ
    // lambda = 50.9686 * 2**64 
    int128 eta1 = 215100; //21.51 * 10000; η1
    int128 eta2 = 241500; //24.15 * 10000; η2
    int128 _p = 5645; //0.5645 * 10000;
    int128 _q = 4355; //0.4355 * 10000;

    int128 alpha = 600000; //6 * 10000
    int128 _pcpct = 100; //0.01*10000 pccp价格
    int128 _V = 1000000000000000; //10000000000*10000 btc全球总交易量

    struct DeltaItem {
        int128 delta; //10**10  2**64  int128
        int128 L1; //10**10
        int128 L2; //10**10
        int128 L3; //10**10
        int128 L4; //10**10
    }
    mapping(int128 => DeltaItem) private _deltaTable;

    // 用户的 nft 列表
    // user => [ids]
    mapping(address => uint256[]) private _idBalance;

    struct NftData {
        int128 delta;
        uint256 pid;
        int128 lever;
        int128 cppcNum;
        uint256 createTime;
        int128 openPrice;
        bool direction;
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
        int128 _upBtc,
        int128 _downBtc,
        int128 _depositFee,
        int128 _withdrawFee,
        int128 _sigma,
        int128 _lambda,
        int128 _eta1,
        int128 _eta2,
        int128 __p,
        int128 __q,
        int128 __pcpct,
        int128 __V
    ) public onlyOwner {
        upBtc = _upBtc;
        downBtc = _downBtc;
        depositFee = _depositFee;
        withdrawFee = _withdrawFee;
        sigma = _sigma;
        lambda = _lambda;
        eta1 = _eta1;
        eta2 = _eta2;
        _p = __p;
        _q = __q;
        _pcpct = __pcpct;
        _V = __V;
    }

    /**
    配置L表格
    */
    function SetLTable(DeltaItem[] calldata _deltaItem) external onlyOwner {
        uint256 length = _deltaItem.length;
        require(length > 0);
        for (uint256 i = 0; i < length; i++) {
            DeltaItem memory deltaItem = _deltaItem[i];
            int128 _l1 = deltaItem.L1;
            _deltaTable[_l1] = deltaItem;
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

    // 获取NFT信息
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
        // nftData._address = _nftData._address;
        nftData.delta = _nftData.delta;
        nftData.pid = pid;
        nftData.lever = _nftData.lever;
        nftData.cppcNum = _nftData.cppcNum;
        nftData.createTime = _nftData.createTime;
        nftData.openPrice = _nftData.openPrice;
        nftData.direction = _nftData.direction;
        nftData.isEnable = true;

        // getPurchaseQuantity
        return pid;
    }

    // 通过Delta获取配置
    function getDeltaTable(int128 _delta)
        private
        view
        returns (DeltaItem memory _DeltaItem)
    {
        DeltaItem memory deltaItem = _deltaTable[_delta];
        return deltaItem;
    }

    // 获取牛证Omg值
    function getUpOmg(int128 l1, int128 l2) public view returns (int128) {
        int128 _eta1_128 = eta1;
        // int128 _l1_128 = ABDKMath64x64.fromUInt(l1);
        // int128 _l2_128 = ABDKMath64x64.fromUInt(l2);
        int128 _a = ABDKMath64x64.sub(_eta1_128, l1);
        int128 _b = _eta1_128;
        int128 _a1 = l2;
        int128 _b1 = ABDKMath64x64.sub(l2, l1);
        int128 _omg = ABDKMath64x64.mul(
            ABDKMath64x64.div(_a, _b),
            ABDKMath64x64.div(_a1, _b1)
        );
        return _omg;
    }

    // 获取熊证Omg值
    function getDownOmg(int128 l3, int128 l4) public view returns (int128) {
        int128 _eta2_128 = eta2;
        // int128 _l1_128 = ABDKMath64x64.fromUInt(l1);
        // int128 _l2_128 = ABDKMath64x64.fromUInt(l2);
        int128 _a = ABDKMath64x64.sub(_eta2_128, l3);
        int128 _b = _eta2_128;
        int128 _a1 = l4;
        int128 _b1 = ABDKMath64x64.sub(l4, l3);
        int128 _omg = ABDKMath64x64.mul(
            ABDKMath64x64.div(_a, _b),
            ABDKMath64x64.div(_a1, _b1)
        );
        return _omg;
    }

    // 获取开仓算数量
    struct Qu {
        bool direction;
        int128 bk;
        int128 delta;
        int128 _i;
    }
    function getPurchaseQuantity(
        Qu memory _qu
    ) public view returns (int128) {
        DeltaItem memory deltaItem = getDeltaTable(_qu.delta);
        
        uint256 l1_uint256 = ABDKMath64x64.mulu(deltaItem.L1, 1);
        uint256 l2_uint256 = ABDKMath64x64.mulu(deltaItem.L2, 1);
        uint256 l3_uint256 = ABDKMath64x64.mulu(deltaItem.L3, 1);
        uint256 l4_uint256 = ABDKMath64x64.mulu(deltaItem.L4, 1);

        int128 omg = getUpOmg(deltaItem.L1, deltaItem.L2);
        if (!_qu.direction) {
            omg = getDownOmg(deltaItem.L3, deltaItem.L4);
        }
        int128 bkPowL1 = ABDKMath64x64.pow(_qu.bk, l1_uint256);
        int128 bkPowL2 = ABDKMath64x64.pow(_qu.bk, l2_uint256);
        int128 bkPowL3 = ABDKMath64x64.pow(_qu.bk, l3_uint256);
        int128 bkPowL4 = ABDKMath64x64.pow(_qu.bk, l4_uint256);
        int128 omg1 = ABDKMath64x64.mul(omg, bkPowL1);
        int128 omg2 = ABDKMath64x64.mul(ABDKMath64x64.sub(1, omg), bkPowL2);

        if (!_qu.direction) {
            omg1 = ABDKMath64x64.div(omg, bkPowL3);
            omg2 = ABDKMath64x64.div(ABDKMath64x64.sub(1, omg), bkPowL4);
        }

        int128 _Q = ABDKMath64x64.div(_qu._i, ABDKMath64x64.add(omg1, omg2));
        return _Q;
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

    function downLiquidation() private view returns (int128) {}

    //  获取TB
    function getTB(
        bool direction,
        int128 B,
        int128 K
    ) private pure returns (int128) {
        uint256 B_uint256 = ABDKMath64x64.mulu(B, 1);
        uint256 K_uint256 = ABDKMath64x64.mulu(K, 1);
        if (direction) {
            // 牛证
            uint256 _TB_uint256 = Math.min(B_uint256, K_uint256);
            int128 _TB_int128 = ABDKMath64x64.fromUInt(_TB_uint256);
            return _TB_int128;
        }
        if (!direction) {
            // 熊证
            uint256 _TB_uint256 = Math.max(B_uint256, K_uint256);
            int128 _TB_int128 = ABDKMath64x64.fromUInt(_TB_uint256);
            return _TB_int128;
        }
    }

    // 获取PBCT
    function getPBCT(
        bool direction,
        int128 delta,
        int128 t,
        int128 B,
        int128 K,
        int128 l1Orl3,
        int128 l2Orl4,
        int128 omg
    ) private pure returns (int128) {
        uint256 l1Orl3_uint256 = ABDKMath64x64.mulu(l1Orl3, 1);
        uint256 l2Orl4_uint256 = ABDKMath64x64.mulu(l2Orl4, 1);
        int128 _tb = getTB(true, B, K);
        int128 _a1 = ABDKMath64x64.div(_tb, K);
        int128 _a1_l1 = ABDKMath64x64.pow(_a1, l1Orl3_uint256);
        int128 _a1_w_l1 = ABDKMath64x64.mul(omg, _a1_l1);

        int128 _a2_l2 = ABDKMath64x64.pow(_a1, l2Orl4_uint256);
        int128 _a2_w_l2 = ABDKMath64x64.mul(ABDKMath64x64.sub(1, omg), _a2_l2);

        if (!direction) {
            _a1_w_l1 = ABDKMath64x64.div(omg, _a1_l1);
            _a2_w_l2 = ABDKMath64x64.div(ABDKMath64x64.sub(1, omg), _a2_l2);
        }

        int128 _a = ABDKMath64x64.add(_a1_w_l1, _a2_w_l2);
        int128 _b = ABDKMath64x64.exp(ABDKMath64x64.mul(delta, t));
        int128 _pbct = ABDKMath64x64.div(_a, _b);
        return _pbct;
    }

    // 获取RL
    function getRL(
        bool direction,
        int128 B,
        int128 K,
        int128 l1Orl3,
        int128 l2Orl4,
        int128 omg
    ) public pure returns (int128) {
        int128 _tb = getTB(true, B, K);
        uint256 l1Orl3_uint256 = ABDKMath64x64.mulu(l1Orl3, 1);
        uint256 l2Orl4_uint256 = ABDKMath64x64.mulu(l2Orl4, 1);
        int128 _a1_l1 = ABDKMath64x64.pow(
            ABDKMath64x64.div(_tb, K),
            l1Orl3_uint256
        );
        int128 _a1 = ABDKMath64x64.mul(ABDKMath64x64.mul(l1Orl3, omg), _a1_l1);

        int128 _a2_l2 = ABDKMath64x64.pow(
            ABDKMath64x64.div(_tb, K),
            l2Orl4_uint256
        );
        int128 _a2 = ABDKMath64x64.mul(
            ABDKMath64x64.mul(l2Orl4, ABDKMath64x64.sub(1, omg)),
            _a2_l2
        );
        if (!direction) {
            _a1 = ABDKMath64x64.div(ABDKMath64x64.mul(l1Orl3, omg), _a1_l1);
            _a2 = ABDKMath64x64.div(
                ABDKMath64x64.mul(l2Orl4, ABDKMath64x64.sub(1, omg)),
                _a2_l2
            );
        }

        int128 _a = ABDKMath64x64.add(_a1, _a2);

        int128 _b1 = ABDKMath64x64.mul(omg, _a1_l1);
        int128 _b2 = ABDKMath64x64.mul(ABDKMath64x64.sub(1, omg), _a2_l2);
        if (!direction) {
            _b1 = ABDKMath64x64.div(omg, _a1_l1);
            _b2 = ABDKMath64x64.div(ABDKMath64x64.sub(1, omg), _a2_l2);
        }
        int128 _b = ABDKMath64x64.add(_b1, _b2);

        int128 _rl = ABDKMath64x64.div(_a, _b);
        return _rl;
    }

    // 获取Priceimpact
    function getPriceimpact(
        int128 lpha,
        int128 delt,
        int128 rl,
        int128 Q,
        int128 pbct
    ) public view returns (int128) {
        int128 a1 = ABDKMath64x64.log_2(ABDKMath64x64.div(_pcpct, _V));
        int128 a2 = ABDKMath64x64.log_2(
            ABDKMath64x64.mul(rl, ABDKMath64x64.mul(Q, pbct))
        );
        int128 _priceimpact = ABDKMath64x64.mul(
            lpha,
            ABDKMath64x64.mul(delt, ABDKMath64x64.mul(a1, a2))
        );
        return _priceimpact;
    }

    // 获取平仓价值
    function getLiquidationNum(
        int128 pbct,
        int128 Q,
        int128 rl,
        int128 priceimpact
    ) private view returns (int128) {
        int128 _a = ABDKMath64x64.mul(
            ABDKMath64x64.sub(1, withdrawFee),
            ABDKMath64x64.mul(pbct, Q)
        );
        int128 _b_1 = ABDKMath64x64.mul(rl, priceimpact);
        uint256 _b_1_uint256 = ABDKMath64x64.mulu(_b_1, 1);
        uint256 _b_2_uint256 = ABDKMath64x64.mulu(1, 1); //toDo 0.1数值转换

        uint256 _b_3_uint256 = Math.min(_b_1_uint256, _b_2_uint256);
        int128 _b_3_uint256_int128 = ABDKMath64x64.fromUInt(_b_3_uint256);
        int128 _b = ABDKMath64x64.add(1, _b_3_uint256_int128);
        int128 _liquidationNum = ABDKMath64x64.div(_a, _b);
        return _liquidationNum;
    }

    function _mintNft(address _to) internal returns (uint256) {
        _mint(_to, _totalSupply);
        return _totalSupply += 1;
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
