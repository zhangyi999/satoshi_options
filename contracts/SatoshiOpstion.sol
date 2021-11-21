//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "hardhat/console.sol";

contract SatoshiOpstion is ERC721, Ownable {
    // 筹码
    address public cppc;

    // 仓位id
    uint256 private _totalSupply = 0;

    int128 currBtc; //当前BTC价格
    // 开仓费率
    int128 depositFee;
    // 平仓费率
    int128 withdrawFee;

    int128 sigma; // 大写Σ，小写σ
    int128 lambda; // λ
    int128 eta1; // η1
    int128 eta2; //η2
    int128 _p; //
    int128 _q; //

    int128 phi; //ϕ
    // int128 alpha; //
    int128 _pcpct; // pccp价格
    int128 r; //SettlementBTCPrice 参数 0.03
    // int128 _V; //10000000000*2**64 btc全球总交易量

    struct DeltaItem {
        int128 delta; //2**64  int128
        int128 L1; //2**64  int128
        int128 L2; //2**64  int128
        int128 L3; //2**64  int128
        int128 L4; //2**64  int128
    }
    mapping(int128 => DeltaItem) private _deltaTable;

    // 用户的 nft 列表
    // user => [ids]
    mapping(address => uint256[]) private _idBalance;

    struct NftData {
        int128 delta;
        uint256 pid;
        int128 cppcNum;
        uint256 createTime;
        int128 openPrice;
        bool direction;
        bool isEnable;
    }
    mapping(uint256 => NftData) private nftStore;

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {
        // cppc = _cppc;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function setCppc(address _cppc) external onlyOwner {
        cppc = _cppc;
    }

    function SetConfig(
        int128 _currBtc,
        int128 _depositFee,
        int128 _withdrawFee,
        int128 _sigma,
        int128 _lambda,
        int128 _eta1,
        int128 _eta2,
        int128 __p,
        int128 __q,
        int128 _phi,
        int128 __pcpct,
        int128 _r
    ) public onlyOwner {
        currBtc = _currBtc;
        depositFee = _depositFee;
        withdrawFee = _withdrawFee;
        sigma = _sigma;
        lambda = _lambda;
        eta1 = _eta1;
        eta2 = _eta2;
        _p = __p;
        _q = __q;
        phi = _phi;
        _pcpct = __pcpct;
        r = _r;
        // _V = __V;
    }

    /**
    配置L表格
    */
    function SetLTable(DeltaItem[] calldata _deltaItem) public onlyOwner {
        uint256 length = _deltaItem.length;
        require(length > 0);
        for (uint256 i = 0; i < length; i++) {
            DeltaItem memory deltaItem = _deltaItem[i];
            int128 _delta = deltaItem.delta;
            _deltaTable[_delta] = deltaItem;
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
    function open(
        bool direction,
        int128 delta,
        int128 bk,
        int128 cppcNum
    ) public returns (uint256 pid) {
        int128 _omg;
        int128 _pbc;
        if (direction) {
            _omg = getUpOmg(delta);
        } else {
            _omg = getDownOmg(delta);
        }
        getPurchaseQuantityInfo
            memory _getPurchaseQuantityInfo = getPurchaseQuantityInfo(
                direction,
                bk,
                delta,
                cppcNum
            );
        _pbc = getPurchaseQuantity(_getPurchaseQuantityInfo);
        console.log("_pbc");
        console.logInt(_pbc);

        pid = _mintNft(_msgSender());

        console.log("_pid");
        console.logUint(pid);
        NftData storage nftData = nftStore[pid];
        // nftData._address = _nftData._address;
        nftData.delta = delta;
        nftData.pid = pid;
        nftData.direction = direction;
        nftData.cppcNum = cppcNum;
        nftData.createTime = block.timestamp;
        nftData.openPrice = currBtc;
        nftData.isEnable = true;

        return pid;
    }

    // 通过Delta获取配置
    function getDeltaTable(int128 _delta)
        public
        view
        returns (DeltaItem memory _DeltaItem)
    {
        DeltaItem memory deltaItem = _deltaTable[_delta];
        return deltaItem;
    }

    // 获取牛证Omg值
    function getUpOmg(int128 _delta) public view returns (int128) {
        int128 _eta1_128 = eta1;
        DeltaItem memory _DeltaItem = getDeltaTable(_delta);
        int128 L1 = _DeltaItem.L1;
        int128 L2 = _DeltaItem.L2;
        int128 _omg = ABDKMath64x64.mul(
            ABDKMath64x64.div(ABDKMath64x64.sub(_eta1_128, L1), _eta1_128),
            ABDKMath64x64.div(L2, ABDKMath64x64.sub(L2, L1))
        );
        return _omg;
    }

    // 获取熊证Omg值
    function getDownOmg(int128 _delta) public view returns (int128) {
        int128 _eta2_128 = eta2;
        DeltaItem memory _DeltaItem = getDeltaTable(_delta);
        int128 L3 = _DeltaItem.L3;
        int128 L4 = _DeltaItem.L4;
        int128 _omg = ABDKMath64x64.mul(
            ABDKMath64x64.div(ABDKMath64x64.sub(_eta2_128, L3), _eta2_128),
            ABDKMath64x64.div(L4, ABDKMath64x64.sub(L4, L3))
        );
        return _omg;
    }

    // 获取K
    function getBk(int128 bk) public view returns (int128) {
        int128 k = ABDKMath64x64.div(currBtc, bk);
        return k;
    }

    // 获取开仓算数量
    struct getPurchaseQuantityInfo {
        bool direction;
        int128 bk;
        int128 delta;
        int128 _i;
    }

    function getPurchaseQuantity(
        getPurchaseQuantityInfo memory _getPurchaseQuantityInfo
    ) public view returns (int128) {
        // console.logBool(_getPurchaseQuantityInfo[0]);
        DeltaItem memory deltaItem = getDeltaTable(
            _getPurchaseQuantityInfo.delta
        );
        int128 delta = _getPurchaseQuantityInfo.delta;
        uint256 l1_uint256 = ABDKMath64x64.mulu(deltaItem.L1, 1);
        uint256 l2_uint256 = ABDKMath64x64.mulu(deltaItem.L2, 1);
        uint256 l3_uint256 = ABDKMath64x64.mulu(deltaItem.L3, 1);
        uint256 l4_uint256 = ABDKMath64x64.mulu(deltaItem.L4, 1);

        int128 omg = getUpOmg(delta);
        if (!_getPurchaseQuantityInfo.direction) {
            omg = getDownOmg(delta);
        }
        // int128 bkPowL1 = ABDKMath64x64.pow(
        //     _getPurchaseQuantityInfo.bk,
        //     l1_uint256
        // );
        // int128 bkPowL2 = ABDKMath64x64.pow(
        //     _getPurchaseQuantityInfo.bk,
        //     l2_uint256
        // );
        // int128 bkPowL3 = ABDKMath64x64.pow(
        //     _getPurchaseQuantityInfo.bk,
        //     l3_uint256
        // );
        // int128 bkPowL4 = ABDKMath64x64.pow(
        //     _getPurchaseQuantityInfo.bk,
        //     l4_uint256
        // );
        int128 omg1 = ABDKMath64x64.mul(
            omg,
            ABDKMath64x64.pow(_getPurchaseQuantityInfo.bk, l1_uint256)
        );
        int128 omg2 = ABDKMath64x64.mul(
            ABDKMath64x64.sub(1 * 2**64, omg),
            ABDKMath64x64.pow(_getPurchaseQuantityInfo.bk, l2_uint256)
        );

        if (!_getPurchaseQuantityInfo.direction) {
            omg1 = ABDKMath64x64.div(
                omg,
                ABDKMath64x64.pow(_getPurchaseQuantityInfo.bk, l3_uint256)
            );
            omg2 = ABDKMath64x64.div(
                ABDKMath64x64.sub(1 * 2**64, omg),
                ABDKMath64x64.pow(_getPurchaseQuantityInfo.bk, l4_uint256)
            );
        }
        // console.log("omg1");
        // console.logInt(omg1);
        // console.log("omg2");
        // console.logInt(omg2);
        int128 _Q = ABDKMath64x64.div(
            _getPurchaseQuantityInfo._i,
            ABDKMath64x64.add(omg1, omg2)
        );
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
    function getTB(bool direction, int128 BK) public view returns (int128) {
        uint256 B_uint256 = ABDKMath64x64.mulu(currBtc, 1);
        int128 K = getBk(BK);
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

    struct getPBCTInfo {
        bool direction;
        int128 delta;
        int128 t;
        int128 BK;
    }

    // 获取PBCT
    function getPBCT(getPBCTInfo memory _getPBCTInfo)
        public
        view
        returns (int128)
    {
        int128 l1Orl3;
        int128 l2Orl4;
        int128 omg;
        DeltaItem memory _DeltaItem = getDeltaTable(_getPBCTInfo.delta);
        if (_getPBCTInfo.direction) {
            l1Orl3 = _DeltaItem.L1;
            l2Orl4 = _DeltaItem.L2;
            omg = getUpOmg(_getPBCTInfo.delta);
        } else {
            l1Orl3 = _DeltaItem.L3;
            l2Orl4 = _DeltaItem.L4;
            omg = getDownOmg(_getPBCTInfo.delta);
        }

        // uint256 l1Orl3_uint256 = ABDKMath64x64.mulu(l1Orl3, 1);
        // uint256 l2Orl4_uint256 = ABDKMath64x64.mulu(l2Orl4, 1);
        // int128 K = getBk(_getPBCTInfo.BK);
        // int128 _tb = getTB(true, _getPBCTInfo.BK);
        int128 _a1 = ABDKMath64x64.div(
            getTB(true, _getPBCTInfo.BK),
            getBk(_getPBCTInfo.BK)
        );
        int128 _a1_l1 = ABDKMath64x64.pow(_a1, ABDKMath64x64.mulu(l1Orl3, 1));
        int128 _a1_w_l1 = ABDKMath64x64.mul(omg, _a1_l1);

        int128 _a2_l2 = ABDKMath64x64.pow(_a1, ABDKMath64x64.mulu(l2Orl4, 1));
        int128 _a2_w_l2 = ABDKMath64x64.mul(ABDKMath64x64.sub(1, omg), _a2_l2);

        if (!_getPBCTInfo.direction) {
            _a1_w_l1 = ABDKMath64x64.div(omg, _a1_l1);
            _a2_w_l2 = ABDKMath64x64.div(
                ABDKMath64x64.sub(1 * 2**64, omg),
                _a2_l2
            );
        }

        // int128 _a = ABDKMath64x64.add(_a1_w_l1, _a2_w_l2);
        // int128 _b = ABDKMath64x64.exp_2(
        //     ABDKMath64x64.mul(_getPBCTInfo.delta, _getPBCTInfo.t)
        // );
        console.log("_getPBCTInfo.delta %s | _getPBCTInfo.t %s", uint128(_getPBCTInfo.delta), uint128(_getPBCTInfo.t));
        int128 _deltaT = ABDKMath64x64.mul(_getPBCTInfo.delta, _getPBCTInfo.t);
        console.log("_deltaT");
        console.logInt(_deltaT);
        int128 _expNum = ABDKMath64x64.exp_2(_deltaT);
        console.log("_expNum");
        console.logInt(_expNum);
        int128 _pbct = ABDKMath64x64.div(
            ABDKMath64x64.add(_a1_w_l1, _a2_w_l2),
            ABDKMath64x64.exp_2(_deltaT)
        );
        return _pbct;
    }

    struct GetRlInfo {
        bool direction;
        int128 delta;
        int128 BK;
    }

    // 获取RL
    function getRL(bool direction, GetRlInfo memory _getRlInfo)
        public
        view
        returns (int128)
    {
        int128 l1Orl3;
        int128 l2Orl4;
        int128 omg;
        DeltaItem memory _DeltaItem = getDeltaTable(_getRlInfo.delta);
        if (_getRlInfo.direction) {
            l1Orl3 = _DeltaItem.L1;
            l2Orl4 = _DeltaItem.L2;
            omg = getUpOmg(_getRlInfo.delta);
        } else {
            l1Orl3 = _DeltaItem.L3;
            l2Orl4 = _DeltaItem.L4;
            omg = getDownOmg(_getRlInfo.delta);
        }

        int128 K = getBk(_getRlInfo.BK);
        int128 _tb = getTB(true, _getRlInfo.BK);
        // uint256 l1Orl3_uint256 = ABDKMath64x64.mulu(l1Orl3, 1);
        // uint256 l2Orl4_uint256 = ABDKMath64x64.mulu(l2Orl4, 1);
        int128 _a1_l1 = ABDKMath64x64.pow(
            ABDKMath64x64.div(_tb, K),
            ABDKMath64x64.mulu(l1Orl3, 1)
        );
        int128 _a1 = ABDKMath64x64.mul(ABDKMath64x64.mul(l1Orl3, omg), _a1_l1);

        int128 _a2_l2 = ABDKMath64x64.pow(
            ABDKMath64x64.div(_tb, K),
            ABDKMath64x64.mulu(l2Orl4, 1)
        );
        int128 _a2 = ABDKMath64x64.mul(
            ABDKMath64x64.mul(l2Orl4, ABDKMath64x64.sub(1 * 2**64, omg)),
            _a2_l2
        );
        int128 _b1 = ABDKMath64x64.mul(omg, _a1_l1);
        int128 _b2 = ABDKMath64x64.mul(
            ABDKMath64x64.sub(1 * 2**64, omg),
            _a2_l2
        );
        if (!direction) {
            _a1 = ABDKMath64x64.div(ABDKMath64x64.mul(l1Orl3, omg), _a1_l1);
            _a2 = ABDKMath64x64.div(
                ABDKMath64x64.mul(l2Orl4, ABDKMath64x64.sub(1 * 2**64, omg)),
                _a2_l2
            );
            _b1 = ABDKMath64x64.div(omg, _a1_l1);
            _b2 = ABDKMath64x64.div(ABDKMath64x64.sub(1 * 2**64, omg), _a2_l2);
        }
        int128 _a = ABDKMath64x64.add(_a1, _a2);
        int128 _b = ABDKMath64x64.add(_b1, _b2);

        int128 _rl = ABDKMath64x64.div(_a, _b);
        return _rl;
    }

    struct GetPriceimpactInfo {
        int128 rl;
        int128 pbct;
        int128 Q;
    }

    // 获取Priceimpact
    function getPriceimpact(GetPriceimpactInfo memory _GetPriceimpactInfo)
        public
        view
        returns (int128)
    {
        int128 a1 = phi;
        int128 a2 = ABDKMath64x64.log_2(
            ABDKMath64x64.mul(
                _GetPriceimpactInfo.rl,
                ABDKMath64x64.mul(
                    _GetPriceimpactInfo.Q,
                    _GetPriceimpactInfo.pbct
                )
            )
        );

        int128 _priceimpact = ABDKMath64x64.mul(a1, a2);
        return _priceimpact;
    }

    struct getLiquidationNumInfo {
        int128 pbct;
        int128 Q;
        int128 rl;
        int128 priceimpact;
    }

    // 获取平仓价值
    function getLiquidationNum(
        getLiquidationNumInfo memory _getLiquidationNumInfo
    ) public view returns (int128) {
        int128 _a = ABDKMath64x64.mul(
            ABDKMath64x64.sub(1 * 2**64, withdrawFee),
            ABDKMath64x64.mul(
                _getLiquidationNumInfo.pbct,
                _getLiquidationNumInfo.Q
            )
        );
        int128 _b_1 = ABDKMath64x64.mul(
            _getLiquidationNumInfo.rl,
            _getLiquidationNumInfo.priceimpact
        );

        uint256 _b_3_uint256 = Math.min(
            ABDKMath64x64.mulu(_b_1, 1),
            ABDKMath64x64.mulu(r, 1) // 0.03数值转换
        );
        int128 _b_3_uint256_int128 = ABDKMath64x64.fromUInt(_b_3_uint256);
        int128 _b = ABDKMath64x64.add(1 * 2**64, _b_3_uint256_int128);
        int128 _liquidationNum = ABDKMath64x64.div(_a, _b);
        return _liquidationNum;
    }

    function _mintNft(address _to) internal returns (uint256) {
        _mint(_to, _totalSupply);
        // console.log("_totalSupply");
        // _totalSupply = _totalSupply + 1;
        // console.logUint(_totalSupply);
        return _totalSupply++;
        // return _totalSupply;
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
