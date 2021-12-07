//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "./libraries/ECDSA.sol";

import "hardhat/console.sol";

interface ERC20Interface {
    function balanceOf(address user) external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;
}

library SafeToken {
    function myBalance(address token) internal view returns (uint256) {
        return ERC20Interface(token).balanceOf(address(this));
    }

    function balanceOf(address token, address user)
        internal
        view
        returns (uint256)
    {
        return ERC20Interface(token).balanceOf(user);
    }

    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "!safeApprove"
        );
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "!safeTransfer"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "!safeTransferFrom"
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "!safeTransferETH");
    }
}

contract SatoshiOpstion1 is ERC721, Ownable {
    using SafeToken for address;

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

    int128 SECONDS_IN_A_YEAR = ABDKMath64x64.fromUInt(31536000);
    address DATA_PROVIDER = 0x9548B3682cD65D3265C92d5111a9782c86Ca886d;

    mapping(address => mapping(uint256 => bool)) private seenNonces;

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
        int128 bk;
        int128 K;
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

    // 设置当前BTC价格
    function _SetCurrBtcPrice(int128 _currBtc) internal {
        currBtc = _currBtc;
    }

    function pow64x64(int128 a, int128 pow) internal pure returns (int128) {
        return
            ABDKMath64x64.exp_2(ABDKMath64x64.mul(pow, ABDKMath64x64.log_2(a)));
    }

    function min(int128 a, int128 b) public pure returns (int128) {
        return a < b ? a : b;
    }

    function max(int128 a, int128 b) public pure returns (int128) {
        return a > b ? a : b;
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

    modifier isMyNFTPid(uint256 _pid) {
        uint256[] memory pids = _idBalance[_msgSender()];
        uint256 length = pids.length;
        bool isMyPid = false;
        if (length > 0) {
            for (uint256 id = 0; id < length; ++id) {
                if (pids[id] == _pid) {
                    isMyPid = true;
                }
            }
        }
        if (isMyPid) {
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

    struct signedPrice {
        int128 tradePrice;
        uint256 nonce;
        bytes signature;
    }

    // 开仓
    function open(
        bool direction,
        int128 delta,
        int128 bk,
        int128 cppcNum,
        address tradeToken,
        signedPrice calldata signedPr
    ) public returns (uint256 pid) {
        int128 _omg;
        int128 _pbc;

        bool isIdentity = _checkIdentity(tradeToken, signedPr);
        console.log("isIdentity");
        console.logBool(isIdentity);
        require(isIdentity, "Price Error.");
        int128 _currBtc = signedPr.tradePrice;
        _SetCurrBtcPrice(_currBtc);

        if (direction) {
            _omg = getUpOmg(delta);
        } else {
            _omg = getDownOmg(delta);
        }

        uint64 _omgUInt = ABDKMath64x64.toUInt(_omg);
        console.log("_omgUInt");
        console.logUint(_omgUInt);
        int128 K = getBk(bk);
        getPurchaseQuantityInfo
            memory _getPurchaseQuantityInfo = getPurchaseQuantityInfo(
                direction,
                bk,
                delta,
                cppcNum
            );
        _pbc = getPurchaseQuantity(_getPurchaseQuantityInfo);
        // console.log("_pbc");
        // console.logInt(_pbc);

        pid = _mintNft(_msgSender());

        // console.log("_pid");
        // console.logUint(pid);
        NftData storage nftData = nftStore[pid];
        // nftData._address = _nftData._address;
        nftData.delta = delta;
        nftData.pid = pid;
        nftData.direction = direction;
        nftData.cppcNum = cppcNum;
        nftData.createTime = (block.timestamp / 1000);
        nftData.openPrice = currBtc;
        nftData.bk = bk;
        nftData.K = K;
        nftData.isEnable = true;
        console.log("_msgSender");
        console.logAddress(_msgSender());
        _burnFor(_msgSender(), ABDKMath64x64.mulu(cppcNum, 1));
        return pid;
    }

    using ECDSA for bytes32;

    //验证前端价格是否正确
    function _checkIdentity(address tradeToken, signedPrice calldata signedPr)
        public
        returns (bool success)
    {
        // This recreates the message hash that was signed on the client.
        int128 tradePrice = signedPr.tradePrice;
        uint256 nonce = signedPr.nonce;
        bytes calldata signature = signedPr.signature;
        bytes32 hash = keccak256(
            abi.encodePacked(tradeToken, tradePrice, nonce, DATA_PROVIDER)
        );
        bytes32 messageHash = hash.toEthSignedMessageHash();

        // Verify that the message's signer is the data provider
        address signer = messageHash.recover(signature);
        console.log("signer");
        console.logAddress(signer);
        console.logAddress(tradeToken);
        console.logAddress(DATA_PROVIDER);
        require(signer == DATA_PROVIDER, "CBBC: INVALID_SIGNER.");

        require(!seenNonces[signer][nonce], "CBBC: USED_NONCE");
        seenNonces[signer][nonce] = true;

        // update the oracle
        // address tradePriceOracle = marketOracle.priceMedianOracles(tradeToken);
        // IMedianOracle(tradePriceOracle).pushReport(tradePrice);
        console.log("ok");
        success = true;
        return success;
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
        int128 k = ABDKMath64x64.mul(currBtc, bk);
        return k;
    }

    struct getEInfo {
        bool direction;
        int128 delta;
        int128 bk;
    }

    // 获取E
    function getE(getEInfo memory _getEInfo) public view returns (int128) {
        int128 l1Orl3;
        int128 l2Orl4;
        int128 omg;
        DeltaItem memory _DeltaItem = getDeltaTable(_getEInfo.delta);
        if (_getEInfo.direction) {
            l1Orl3 = _DeltaItem.L1;
            l2Orl4 = _DeltaItem.L2;
            omg = getUpOmg(_getEInfo.delta);
        } else {
            l1Orl3 = _DeltaItem.L3;
            l2Orl4 = _DeltaItem.L4;
            omg = getDownOmg(_getEInfo.delta);
        }
        int128 K = getBk(_getEInfo.bk);
        int128 a_1 = ABDKMath64x64.mul(omg, l1Orl3);
        int128 a_2 = ABDKMath64x64.mul(
            ABDKMath64x64.sub(1 * 2**64, omg),
            l2Orl4
        );
        int128 a = ABDKMath64x64.mul(ABDKMath64x64.add(a_1, a_2), K);

        int128 b_1 = ABDKMath64x64.mul(omg, l1Orl3);
        int128 b_2 = ABDKMath64x64.mul(
            ABDKMath64x64.sub(1 * 2**64, omg),
            l2Orl4
        );
        int128 b = ABDKMath64x64.sub(ABDKMath64x64.add(b_1, b_2), 1 * 2**64);
        if (!_getEInfo.direction) {
            b = ABDKMath64x64.add(ABDKMath64x64.add(b_1, b_2), 1 * 2**64);
        }

        int128 _e = ABDKMath64x64.div(a, b);
        return _e;
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
        int128 B0 = currBtc;

        int128 omg = getUpOmg(delta);
        if (!_getPurchaseQuantityInfo.direction) {
            omg = getDownOmg(delta);
        }
        getEInfo memory _getEInfo = getEInfo(
            _getPurchaseQuantityInfo.direction,
            _getPurchaseQuantityInfo.delta,
            _getPurchaseQuantityInfo.bk
        );
        int128 _E = getE(_getEInfo);
        console.log("_E");
        console.logInt(_E);
        int128 _K = getBk(_getPurchaseQuantityInfo.bk);
        console.log("_K");
        console.logInt(_K);
        int128 omg1;
        int128 omg2;

        if (_getPurchaseQuantityInfo.direction) {
            omg1 = ABDKMath64x64.mul(
                omg,
                pow64x64(ABDKMath64x64.div(B0, _E), deltaItem.L1)
            );
            omg2 = ABDKMath64x64.mul(
                ABDKMath64x64.sub(1 * 2**64, omg),
                pow64x64(ABDKMath64x64.div(B0, _E), deltaItem.L2)
            );
        } else {
            console.log("B0");
            console.logInt(B0);
            omg1 = ABDKMath64x64.mul(
                omg,
                pow64x64(ABDKMath64x64.div(_E, B0), deltaItem.L3)
            );
            console.log("omg1");
            console.logInt(omg1);
            console.log("L3");
            console.logInt(deltaItem.L3);
            console.log("L4");
            console.logInt(deltaItem.L4);
            pow64x64(ABDKMath64x64.div(_E, B0), deltaItem.L4);
            omg2 = ABDKMath64x64.mul(
                ABDKMath64x64.sub(1 * 2**64, omg),
                pow64x64(ABDKMath64x64.div(_E, B0), deltaItem.L4)
            );
        }
        // console.log("omg");
        // console.logInt(omg);
        // console.log("omg1-rl");

        // console.logInt(_getPurchaseQuantityInfo.bk);

        console.log("omg2-rl");
        console.log("omg2");
        // console.logInt(omg2);
        console.log("P0");
        console.logInt(
            ABDKMath64x64.mul(
                ABDKMath64x64.add(omg1, omg2),
                ABDKMath64x64.sub(_K, _E)
            )
        );
        int128 _Q = ABDKMath64x64.div(
            _getPurchaseQuantityInfo._i,
            ABDKMath64x64.mul(
                ABDKMath64x64.add(omg1, omg2),
                ABDKMath64x64.sub(_E, _K)
            )
        );
        if (!_getPurchaseQuantityInfo.direction) {
            _Q = ABDKMath64x64.div(
                _getPurchaseQuantityInfo._i,
                ABDKMath64x64.mul(
                    ABDKMath64x64.add(omg1, omg2),
                    ABDKMath64x64.sub(_K, _E)
                )
            );
        }
        return _Q;
    }

    // 平仓
    function Withdraw(uint256 _pid, uint256 btcPrice)
        public
        payable
        isMyNFTPid(_pid)
    {
        NftData memory nftData = this.getCppcInfo(_pid);
        nftData.isEnable = false;
        bool direction = nftData.direction;
        int128 delta = nftData.delta;
        int128 currTime = 60 * 60; // ABDKMath64x64.fromUInt(block.timestamp / 1000);
        int128 createTime = ABDKMath64x64.fromUInt(nftData.createTime);
        int128 t = ABDKMath64x64.sub(currTime, createTime);
        int128 bk = nftData.bk;
        int128 cppcNum = nftData.cppcNum;
        int128 K = nftData.K;
        int128 BT = currBtc;
        // console.logInt(delta);
        // console.logInt(t);
        // console.logInt(bk);
        // console.logInt(cppcNum);
        // console.logInt(K);
        getPBCTInfo memory _getPBCTInfo = getPBCTInfo(
            direction,
            bk,
            delta,
            cppcNum,
            K,
            BT
        );
        int128 pbct = getPBCT(_getPBCTInfo);
        console.log("getPBCT--");
        console.logInt(pbct);
        GetRlInfo memory _GetRlInfo = GetRlInfo(direction, delta);
        int128 rl = getRL(_GetRlInfo);
        console.log("getRL--");
        console.logInt(rl);

        GetPriceimpactInfo memory _GetPriceimpactInfo = GetPriceimpactInfo(
            rl,
            pbct,
            cppcNum
        );
        int128 priceimpact = getPriceimpact(_GetPriceimpactInfo);
        console.log("priceimpact--");
        console.logInt(priceimpact);

        getLiquidationNumInfo
            memory _getLiquidationNumInfo = getLiquidationNumInfo(
                pbct,
                cppcNum,
                rl,
                priceimpact
            );
        int128 LiquidationNum = getLiquidationNum(_getLiquidationNumInfo);
        console.log("LiquidationNum--");
        console.logInt(LiquidationNum);
        console.logUint(ABDKMath64x64.mulu(LiquidationNum, 1));
        _mintCppc(_msgSender(), ABDKMath64x64.mulu(LiquidationNum, 1));
        // return LiquidationNum;
    }

    function downLiquidation() private view returns (int128) {}

    //  获取TB
    function getTB(bool direction, int128 K) public view returns (int128) {
        uint256 B_uint256 = ABDKMath64x64.mulu(currBtc, 1);
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
        int128 K;
        int128 BT;
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
        // console.log("getPBCT--");
        // console.logInt(_getPBCTInfo.delta);
        // console.logInt(_getPBCTInfo.t);
        // console.logInt(_getPBCTInfo.K);
        // console.logBool(_getPBCTInfo.direction);
        getEInfo memory _getEInfo = getEInfo(
            _getPBCTInfo.direction,
            _getPBCTInfo.delta,
            _getPBCTInfo.BK
        );
        int128 _E = getE(_getEInfo);
        int128 _Bt = _getPBCTInfo.BT; //to do

        int128 _a = max(0, ABDKMath64x64.sub(_Bt, _getPBCTInfo.K));
        DeltaItem memory _DeltaItem = getDeltaTable(_getPBCTInfo.delta);
        if (_getPBCTInfo.direction) {
            l1Orl3 = _DeltaItem.L1;
            l2Orl4 = _DeltaItem.L2;
            omg = getUpOmg(_getPBCTInfo.delta);
        } else {
            l1Orl3 = _DeltaItem.L3;
            l2Orl4 = _DeltaItem.L4;
            omg = getDownOmg(_getPBCTInfo.delta);
            _a = max(0, ABDKMath64x64.sub(_getPBCTInfo.K, _Bt));
        }
        console.log("_a");
        console.logInt(_a);

        int128 _t = ABDKMath64x64.div(_getPBCTInfo.t, SECONDS_IN_A_YEAR);
        int128 _deltaT = ABDKMath64x64.mul(_getPBCTInfo.delta, _t);
        console.log("getPBCT_deltaT");
        console.logInt(_deltaT);
        int128 _b = ABDKMath64x64.exp(_deltaT);
        console.log("getPBCT_b");
        console.logInt(_b);
        // int128 _expNum = ABDKMath64x64.exp_2(_deltaT);
        // console.log("getPBCT_expNum");
        // console.logInt(_expNum);
        int128 _pbct = ABDKMath64x64.div(_a, _b);
        console.log("getPBCT_pbct");
        console.logInt(_pbct);
        return _pbct;
    }

    struct GetRlInfo {
        bool direction;
        int128 delta;
    }

    function getRL(GetRlInfo memory _getRlInfo) public view returns (int128) {
        int128 l1Orl3;
        int128 l2Orl4;
        int128 _eta;
        DeltaItem memory _DeltaItem = getDeltaTable(_getRlInfo.delta);
        if (_getRlInfo.direction) {
            l1Orl3 = _DeltaItem.L1;
            l2Orl4 = _DeltaItem.L2;
            _eta = eta1;
        } else {
            l1Orl3 = _DeltaItem.L3;
            l2Orl4 = _DeltaItem.L4;
            _eta = eta2;
        }
        int128 _rl = ABDKMath64x64.div(ABDKMath64x64.mul(l1Orl3, l2Orl4), _eta);
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
        int128 _b = ABDKMath64x64.mul(
            _GetPriceimpactInfo.Q,
            _GetPriceimpactInfo.pbct
        );
        int128 _c = ABDKMath64x64.mul(_GetPriceimpactInfo.rl, _b);
        console.log("_b");
        console.logInt(_b);
        console.log("_c");
        console.logInt(_c);
        int128 a2 = ABDKMath64x64.sqrt(_c);
        console.log("a2");
        console.logInt(a2);

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
        console.log("_a");
        console.logInt(_a);
        int128 _b_1 = ABDKMath64x64.mul(
            _getLiquidationNumInfo.rl,
            _getLiquidationNumInfo.priceimpact
        );

        console.log("_b_1");
        console.logInt(_b_1);
        console.logInt(r);
        int128 _b_3 = min(
            _b_1,
            r // 0.03数值转换
        );

        console.log("_b_3");
        console.logInt(_b_3);
        int128 _b = ABDKMath64x64.add(1 * 2**64, _b_3);
        console.log("_b");
        console.logInt(_b);
        int128 _liquidationNum = ABDKMath64x64.div(_a, _b);
        return _liquidationNum;
    }

    function _mintNft(address _to) internal returns (uint256) {
        _mint(_to, _totalSupply);
        return _totalSupply++;
    }

    // 记录 id
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        _idBalance[to].push(tokenId);
    }

    function _mintCppc(address to, uint256 amount) internal {
        ERC20Interface(cppc).mint(to, amount);
    }

    function _burnFor(address from, uint256 amount) internal {
        console.log("_burnFor");
        console.logUint(amount);
        console.logAddress(from);
        console.log("cppcAddress");
        console.logAddress(cppc);
        cppc.safeTransferFrom(from, address(this), amount);
        ERC20Interface(cppc).burn(amount);
    }
}
