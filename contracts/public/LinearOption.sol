//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "../interface/IConfig.sol";

library LinearOption {

    using ABDKMath64x64 for int128;

    struct GetPBCTInfo {
        bool direction;
        int128 delta;
        int128 t;
        int128 BK;
        int128 K;
        int128 BT;
    }

    // 获取开仓算数量
    struct GetPurchaseQuantityInfo {
        bool direction;
        int128 bk;
        int128 delta;
        int128 _i;
    }

    struct GetEInfo {
        bool direction;
        int128 delta;
        int128 bk;
    }

    //////////// 64x64 ////////////
    function pow64x64(int128 a, int128 pow) public pure returns (int128) {
        return (pow.mul(a.log_2())).exp_2();
    }

    function min128(int128 a, int128 b) public pure returns (int128) {
        return a < b ? a : b;
    }

    function max128(int128 a, int128 b) public pure returns (int128) {
        return a > b ? a : b;
    }

    function getUpOmg(int128 _eta1_128, int128 L1, int128 L2) public pure returns (int128) {
        return _eta1_128.sub(L1).div(_eta1_128).mul(L2.div(L2.sub(L1)));
    }

    function getDownOmg(int128 _eta2_128, int128 L3, int128 L4) public pure returns (int128) {
        return _eta2_128.sub(L3).div(_eta2_128).mul(L4.div(L4.sub(L3)));
    }

    // 获取K
    function getBk(int128 currBtc,int128 bk) public pure returns (int128) {
        return currBtc.mul(bk);
    }

    // 获取E
    function getE(
        GetEInfo memory _getEInfo,
        IConfig.DeltaItem memory _DeltaItem,
        int128 _eta1_128,
        int128 _eta2_128,
        int128 currBtc
    ) public pure returns (int128) {
        int128 l1Orl3;
        int128 l2Orl4;
        int128 omg;
        int128 _int = 1 << 64;

        if (_getEInfo.direction) {
            l1Orl3 = _DeltaItem.L1;
            l2Orl4 = _DeltaItem.L2;
            omg = getUpOmg(
                _eta1_128,
                l1Orl3,
                l2Orl4
            );
        } else {
            l1Orl3 = _DeltaItem.L3;
            l2Orl4 = _DeltaItem.L4;
            omg = getDownOmg(
                _eta2_128,
                l1Orl3,
                l2Orl4
            );
        }
        int128 K = getBk(currBtc, _getEInfo.bk);
        
        // 这里的 a_2 和 b_2 需要检查 
        int128 a_1 = omg.mul(l1Orl3);
        int128 a_2 = l2Orl4.mul(
            _int.sub(omg)
        );
        int128 a =  K.mul(a_1.add(a_2));
        int128 b = _getEInfo.direction ?
            a_1.add(a_2).add(_int) :
            a_1.add(a_2).sub(_int);
        int128 _e = a.div(b);
        return _e;
    }


    function getPurchaseQuantity(
        GetPurchaseQuantityInfo memory _getPurchaseQuantityInfo,
        IConfig.DeltaItem memory deltaItem,
        int128 eta1,
        int128 eta2,
        int128 currBtc
    ) public pure returns (int128) {
        int128 B0 = currBtc;
        int128 omg = _getPurchaseQuantityInfo.direction ?
            getUpOmg(
                eta1,
                deltaItem.L1,
                deltaItem.L2
            ) :
            getDownOmg(
                eta2,
                deltaItem.L3,
                deltaItem.L4
            );
        int128 _E = getE(
            GetEInfo(
                _getPurchaseQuantityInfo.direction,
                _getPurchaseQuantityInfo.delta,
                _getPurchaseQuantityInfo.bk
            ),
            deltaItem,
            eta1,
            eta2,
            B0
        );
        int128 _K = getBk(currBtc,  _getPurchaseQuantityInfo.bk);
        int128 omg1;
        int128 omg2;

        if (_getPurchaseQuantityInfo.direction) {
            omg1 = omg.mul(pow64x64(B0.div(_E), deltaItem.L1));
            omg2 = (int128(1<<64).sub(omg)).mul(pow64x64(B0.div(_E), deltaItem.L2));
        } else {
            omg1 = omg.mul(pow64x64(_E.div(B0), deltaItem.L3));
            omg2 = (int128(1<<64).sub(omg)).mul(pow64x64(_E.div(B0), deltaItem.L4));
        }

        int128 _Q = _getPurchaseQuantityInfo.direction?
            _getPurchaseQuantityInfo._i.div(
                (omg1.add(omg2)).mul(_K.sub(_E))
            ):
            _getPurchaseQuantityInfo._i.div(
                (omg1.add(omg2)).mul(_E.sub(_K))
            );

        return _Q;
    }

    //  获取TB
    function getTB(bool direction, int128 K, int128 currBtc)
        public
        pure
        returns (int128 _TB_int128)
    {
        if (direction) {
            _TB_int128 = min128(currBtc, K);
        } else {
            _TB_int128 = max128(currBtc, K);
        }
    }

    function getPBCT(
        GetPBCTInfo memory _getPBCTInfo,
        IConfig.DeltaItem memory _DeltaItem,
        int128 _eta1,
        int128 _eta2
    )
        public
        pure
        returns (int128)
    {
        int128 l1Orl3;
        int128 l2Orl4;
        int128 omg;
        int128 _Bt = _getPBCTInfo.BT;
        
        int128 _a;
        if (_getPBCTInfo.direction) {
            l1Orl3 = _DeltaItem.L1;
            l2Orl4 = _DeltaItem.L2;
            omg = getUpOmg(
                _eta1,
                l1Orl3,
                l2Orl4
            );
            _a = max128(0, _Bt.sub(_getPBCTInfo.K));
        } else {
            l1Orl3 = _DeltaItem.L3;
            l2Orl4 = _DeltaItem.L4;
            omg = getDownOmg(
                _eta2,
                l1Orl3,
                l2Orl4
            );
            _a = max128(0, _getPBCTInfo.K.sub(_Bt));
        }
        // SECONDS_IN_A_YEAR 581736521108504419762176000 
        int128 _t = _getPBCTInfo.t.div(581736521108504419762176000);
        int128 _deltaT = _getPBCTInfo.delta.mul(_t);
        int128 _b = _deltaT.exp();
        return _a.div(_b);
    }

    struct GetRlInfo {
        bool direction;
        int128 delta;
    }

    function getRL(
        GetRlInfo memory _getRlInfo,
        IConfig.DeltaItem memory _DeltaItem,
        int128 eta1,
        int128 eta2
    ) public pure returns (int128) {
        int128 l1Orl3;
        int128 l2Orl4;
        int128 _eta;
        if (_getRlInfo.direction) {
            l1Orl3 = _DeltaItem.L1;
            l2Orl4 = _DeltaItem.L2;
            _eta = eta1;
        } else {
            l1Orl3 = _DeltaItem.L3;
            l2Orl4 = _DeltaItem.L4;
            _eta = eta2;
        }
        return l1Orl3.mul(l2Orl4).div(_eta);
    }

    struct GetPriceimpactInfo {
        int128 rl;
        int128 pbct;
        int128 Q;
        int128 phi;
    }

    function getPriceimpact(
        int128 rl,
        int128 pbct,
        int128 Q,
        int128 phi
    )
        public
        pure
        returns (int128)
    {
        int128 _b = Q.mul(pbct);
        int128 _c = rl.mul(_b);
        int128 a2 = _c.sqrt();
        return phi.mul(a2);
    }

    struct GetLiquidationNumInfo {
        int128 pbct;
        int128 Q;
        int128 rl;
        int128 priceimpact;
    }

    // 获取平仓价值
    function _getLiquidationNum(
        GetLiquidationNumInfo memory _getLiquidationNumInfo,
        int128 withdrawFee,
        int128 r
    ) internal pure returns (int128) {
        int128 _int = 1 << 64;
        int128 _a = _int.sub(withdrawFee).mul(_getLiquidationNumInfo.pbct.mul(_getLiquidationNumInfo.Q));
        int128 _b_1 = _getLiquidationNumInfo.rl.mul(_getLiquidationNumInfo.priceimpact);
        int128 _b_3 = min128(
            _b_1,
            r
        );
        int128 _b = _b_3.add(_int);
        int128 _liquidationNum = _a.div(_b);
        return _liquidationNum;
    }

    function getLiquidationNum(
        GetPBCTInfo memory BTCInfo,
        IConfig.DeltaItem memory _DeltaItem,
        int128 eta1,
        int128 eta2,
        int128 phi,
        int128 withdrawFee,
        int128 r
    ) public pure returns (int128) {
        int128 pbct = getPBCT(
            BTCInfo,
            _DeltaItem,
            eta1,
            eta2
        );

        int128 rl = getRL(
            GetRlInfo(BTCInfo.direction, BTCInfo.delta),
            _DeltaItem,
            eta1,
            eta2
        );

        int128 priceimpact = getPriceimpact(
            rl,
            pbct,
            BTCInfo.t,
            phi
        );
        return _getLiquidationNum(
            LinearOption.GetLiquidationNumInfo(
                pbct,
                BTCInfo.K,
                rl,
                priceimpact
            ),
            withdrawFee,
            r
        );
    }
}