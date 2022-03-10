// "use strict";
// exports.__esModule = true;
// var bignumber_js_1 = require("bignumber.js");
// var ethers_1 = require("ethers");
// function getInt128(num) {
//     var _num = (new bignumber_js_1.BigNumber(num).multipliedBy(new bignumber_js_1.BigNumber(2).pow(64))).toString(10);
//     _num = _num.split('.')[0];
//     // console.log("_num", _num);
//     return ethers_1.BigNumber.from(_num);
// }
// function int128Div(a, b) {
//     var _c = ethers_1.BigNumber.from(2).pow(64);
//     var _d = a.mul(_c).div(b);
//     return ethers_1.BigNumber.from(_d.toString().split('.')[0]);
// }
// function int128Mul(a, b) {
//     var _c = ethers_1.BigNumber.from(2).pow(64);
//     var _d = a.mul(b).div(_c);
//     return ethers_1.BigNumber.from(_d.toString().split('.')[0]);
// }
// function int128ToDecimal(num) {
//     var _num = new bignumber_js_1.BigNumber(num).dividedBy(UNIT64.toString()).toNumber();
//     return _num;
// }
// var MAX_UINT256 = ethers_1.BigNumber.from(2).pow(256).sub(1);
// var UNIT64 = ethers_1.BigNumber.from(2).pow(64);
// var SECONDS_IN_A_YEAR = 31536000;
// var currBtc = 65000;
// var depositFee = 0.01;
// var withdrawFee = 0.01;
// var r = 0.03;
// var sigma = 1;
// var lambda = 50.9684;
// var eta1 = "21.51";
// var eta2 = "24.15";
// var p = "0.5645";
// var q = "0.4355";
// var phi = "0.00000036";
// var pcpct = 0.01;
// var ltable = [
//     {
//         delta: "2",
//         l1: "2.365409217",
//         l2: "24.2290085",
//         l3: "1.424722727",
//         l4: "25.841622"
//     },
//     {
//         delta: "6",
//         l1: "3.65446369",
//         l2: "24.266891",
//         l3: "4.032382035",
//         l4: "25.90249482"
//     },
//     {
//         delta: "8760",
//         l1: "133.7577595",
//         l2: "21.43795928",
//         l3: "131.7684318",
//         l4: "24.0887339"
//     },
//     {
//         delta: "525600",
//         l1: "1026.321008",
//         l2: "21.50882215",
//         l3: "1024.340376",
//         l4: "24.14898351"
//     }
// ];
// function getOmega(eta1, L1, L2) {
//     var _eta1 = getInt128(eta1);
//     var _L1 = getInt128(L1);
//     var _L2 = getInt128(L2);
//     var omgc = int128Mul(int128Div(_eta1.sub(_L1), _eta1), int128Div(_L2, _L2.sub(_L1)));
//     return omgc;
// }
// function calculatePrice0(eta, L1, L2, R) {
//     var omgc = getOmega(eta, L1, L2);
//     var expExpression1 = getInt128(Math.pow(new bignumber_js_1.BigNumber(R).toNumber(), new bignumber_js_1.BigNumber(L1).toNumber()).toString());
//     var expExpression2 = getInt128(Math.pow(new bignumber_js_1.BigNumber(R).toNumber(), new bignumber_js_1.BigNumber(L2).toNumber()).toString());
//     var pb0 = int128Div(omgc, expExpression1).add(int128Div(UNIT64.sub(omgc), expExpression2));
//     return pb0;
// }
// function getK(B0, R) {
//     return int128Mul(getInt128(B0), getInt128(R));
// }
// function getRL(eta, L1, L2) {
//     var RL = new bignumber_js_1.BigNumber(L1).multipliedBy(L2).dividedBy(eta).toString();
//     return getInt128(RL);
// }
// function priceImpact(RL, Q, pricet) {
//     var num = int128Mul(int128Mul(ethers_1.BigNumber.from(RL), ethers_1.BigNumber.from(Q)), ethers_1.BigNumber.from(pricet));
//     var den = int128ToDecimal(num.toString());
//     var result = new bignumber_js_1.BigNumber(phi).multipliedBy(Math.sqrt(den)).toString();
//     return getInt128(result);
// }
// // t: seconds elapsed since the beginning of purchase
// function calculateCallPricet(t, delta, L1, L2, R, B0, Bt) {
//     var decay = Math.exp(-new bignumber_js_1.BigNumber(delta).multipliedBy(new bignumber_js_1.BigNumber(t)).dividedBy(SECONDS_IN_A_YEAR)).toString();
//     var omegaC = getOmega(eta1, L1, L2);
//     var K = getK(B0, R);
//     var _Bt = getInt128(Bt);
//     var TB = K.gt(_Bt) ? _Bt : K;
//     var TBK = new bignumber_js_1.BigNumber(TB.toString()).dividedBy(new bignumber_js_1.BigNumber(K.toString()));
//     var expExpression1 = int128Mul(omegaC, getInt128(Math.pow(TBK.toNumber(), new bignumber_js_1.BigNumber(L1).toNumber()).toString()));
//     var expExpression2 = int128Mul(UNIT64.sub(omegaC), getInt128(Math.pow(TBK.toNumber(), new bignumber_js_1.BigNumber(L2).toNumber()).toString()));
//     var pbt = int128Mul(expExpression1.add(expExpression2), getInt128(decay));
//     return pbt;
// }
// function calculatePutPricet(t, delta, L3, L4, R, B0, Bt) {
//     var decay = Math.exp(-new bignumber_js_1.BigNumber(delta).multipliedBy(new bignumber_js_1.BigNumber(t)).dividedBy(SECONDS_IN_A_YEAR)).toString();
//     var omegaC = getOmega(eta2, L3, L4);
//     var K = getK(B0, R);
//     var _Bt = getInt128(Bt);
//     var TB = K.lt(_Bt) ? _Bt : K;
//     var TBK = new bignumber_js_1.BigNumber(TB.toString()).dividedBy(new bignumber_js_1.BigNumber(K.toString()));
//     var expExpression1 = int128Mul(omegaC, getInt128(Math.pow(TBK.toNumber(), -new bignumber_js_1.BigNumber(L3).toNumber()).toString()));
//     var expExpression2 = int128Mul(UNIT64.sub(omegaC), getInt128(Math.pow(TBK.toNumber(), -new bignumber_js_1.BigNumber(L4).toNumber()).toString()));
//     var pbt = int128Mul(expExpression1.add(expExpression2), getInt128(decay));
//     return pbt;
// }
// // calculate the price of the contiuous payoff option
// function getEC(L1, L2, R, B0) {
//     var omgc = getOmega(eta1, L1, L2);
//     var _L1 = getInt128(L1);
//     var _L2 = getInt128(L2);
//     var numerator = int128Mul(_L1, omgc).add(int128Mul(_L2, UNIT64.sub(omgc)));
//     var denominator = int128Mul(_L1, omgc).add(int128Mul(_L2, UNIT64.sub(omgc))).sub(UNIT64);
//     var K = getK(B0, R);
//     return int128Div(int128Mul(numerator, K), denominator);
// }
// function getFC(L1, L2, R, B0) {
//     var omgc = getOmega(eta1, L1, L2);
//     var Ec = getEC(L1, L2, R, B0);
//     var Ecr = new bignumber_js_1.BigNumber(Ec.toString()).dividedBy(new bignumber_js_1.BigNumber(UNIT64.toString())).multipliedBy(new bignumber_js_1.BigNumber(R)).toNumber();
//     var denominator1 = Math.pow(Ecr, new bignumber_js_1.BigNumber(L1).toNumber());
//     var denominator2 = Math.pow(Ecr, new bignumber_js_1.BigNumber(L2).toNumber());
//     var result = int128Div(omgc, getInt128(denominator1.toString())).add(int128Div(UNIT64.sub(omgc), getInt128(denominator2.toString())));
//     return int128Mul(result, Ec.sub(UNIT64));
// }
// function calculateContinuousCallPrice0(L1, L2, R, B0) {
//     var K = getK(B0, R);
//     var omgc = getOmega(eta1, L1, L2);
//     var Ec = getEC(L1, L2, R, B0);
//     var Ecr = new bignumber_js_1.BigNumber(getInt128(B0).toString()).dividedBy(Ec.toString()).toNumber();
//     var denominator1 = Math.pow(Ecr, new bignumber_js_1.BigNumber(L1).toNumber());
//     var denominator2 = Math.pow(Ecr, new bignumber_js_1.BigNumber(L2).toNumber());
//     var result = int128Mul(omgc, getInt128(denominator1.toString())).add(int128Mul(UNIT64.sub(omgc), getInt128(denominator2.toString())));
//     return int128Mul(result, Ec.sub(K));
// }
// // t: seconds elapsed since the beginning of purchase
// /*
// function calculateContinuousCallPricet(t:string, delta:string, L1:string, L2:string, R:string, B0:string, Bt:string): BigNumber{
//   let decay: string = Math.exp(-new BN(delta).multipliedBy(new BN(t)).dividedBy(SECONDS_IN_A_YEAR)).toString();
//   let omegaC:BigNumber = getOmega(eta1, L1, L2);
//   let Ec:BigNumber = getEC(L1, L2, R, B0);
//   let K:BigNumber = getK(B0, R);
//   let _Bt = getInt128(Bt);
//   let TBK:BN;
//   let expExpression1:BigNumber;
//   let expExpression2:BigNumber;
//   let pbt:BigNumber;

//   if(_Bt.gte(int128Mul(K, Ec))){
//     return int128Mul(_Bt.sub(K), getInt128(decay));
//   }else{
//     TBK = new BN(int128Div(_Bt, int128Mul(K, Ec)).toString()).dividedBy(new BN(UNIT64.toString()));
//     expExpression1 = int128Mul(omegaC, getInt128(Math.pow(TBK.toNumber(), new BN(L1).toNumber()).toString()));
//     expExpression2 = int128Mul(UNIT64.sub(omegaC), getInt128(Math.pow(TBK.toNumber(), new BN(L2).toNumber()).toString()));
//     pbt = int128Mul(int128Mul(expExpression1.add(expExpression2), Ec.sub(UNIT64)), int128Mul(getInt128(decay), K));

//     return pbt;
//   }

// }
// */
// function calculateContinuousCallPricet(t, delta, R, B0, Bt) {
//     var decay = Math.exp(-new bignumber_js_1.BigNumber(delta).multipliedBy(new bignumber_js_1.BigNumber(t)).dividedBy(SECONDS_IN_A_YEAR)).toString();
//     var K = getK(B0, R);
//     var _Bt = getInt128(Bt);
//     var pbt = _Bt.gt(K) ? int128Mul(_Bt.sub(K), getInt128(decay)) : getInt128("0");
//     return pbt;
// }
// function getEP(L3, L4, R, B0) {
//     var omgp = getOmega(eta2, L3, L4);
//     var _L3 = getInt128(L3);
//     var _L4 = getInt128(L4);
//     var K = getK(B0, R);
//     var numerator = int128Mul(_L3, omgp).add(int128Mul(_L4, UNIT64.sub(omgp)));
//     var denominator = int128Mul(_L3, omgp).add(int128Mul(_L4, UNIT64.sub(omgp))).add(UNIT64);
//     return int128Div(int128Mul(numerator, K), denominator);
// }
// /*
// function getFP(L3:string, L4:string, R:string):BigNumber{
//   let omgp:BigNumber = getOmega(eta2, L3, L4);
//   let Ep:BigNumber = getEP(L3, L4);
//   let Epr:number = new BN(Ep.toString()).dividedBy(new BN(UNIT64.toString())).multipliedBy(new BN(R)).toNumber();

//   let denominator1:number = Math.pow(Epr, new BN(L3).toNumber());
//   let denominator2:number = Math.pow(Epr, new BN(L4).toNumber());

//   let result:BigNumber = int128Mul(omgp, getInt128(denominator1.toString())).add(int128Mul(UNIT64.sub(omgp), getInt128(denominator2.toString())));

//   return int128Mul(result, UNIT64.sub(Ep));
// }
// */
// function calculateContinuousPutPrice0(L3, L4, R, B0) {
//     var K = getK(B0, R);
//     var omgc = getOmega(eta2, L3, L4);
//     var Ep = getEP(L3, L4, R, B0);
//     var Epr = new bignumber_js_1.BigNumber(Ep.toString()).dividedBy(getInt128(B0).toString()).toNumber();
//     var denominator1 = Math.pow(Epr, new bignumber_js_1.BigNumber(L3).toNumber());
//     var denominator2 = Math.pow(Epr, new bignumber_js_1.BigNumber(L4).toNumber());
//     var result = int128Mul(omgc, getInt128(denominator1.toString())).add(int128Mul(UNIT64.sub(omgc), getInt128(denominator2.toString())));
//     return int128Mul(result, K.sub(Ep));
// }
// /*
// function calculateContinuousPutPricet(t:string, delta:string, L3:string, L4:string, R:string, B0:string, Bt:string): BigNumber{
//   let decay: string = Math.exp(-new BN(delta).multipliedBy(new BN(t)).dividedBy(SECONDS_IN_A_YEAR)).toString();
//   let omegaP:BigNumber = getOmega(eta2, L3, L4);
//   let Ep:BigNumber = getEP(L3, L4);
//   let K:BigNumber = getK(B0, R);
//   let _Bt = getInt128(Bt);
//   let TBK:BN;
//   let expExpression1:BigNumber;
//   let expExpression2:BigNumber;
//   let pbt:BigNumber;

//   if(_Bt.lte(int128Mul(K, Ep))){
//     return int128Mul(K.sub(_Bt), getInt128(decay));
//   }else{
//     TBK = new BN(int128Div(_Bt, int128Mul(K, Ep)).toString()).dividedBy(new BN(UNIT64.toString()));
//     expExpression1 = int128Mul(omegaP, getInt128(Math.pow(TBK.toNumber(), -new BN(L3).toNumber()).toString()));
//     expExpression2 = int128Mul(UNIT64.sub(omegaP), getInt128(Math.pow(TBK.toNumber(), -new BN(L4).toNumber()).toString()));
//     pbt = int128Mul(int128Mul(expExpression1.add(expExpression2), UNIT64.sub(Ep)), int128Mul(getInt128(decay), K));

//     return pbt;
//   }

// }
// */
// function calculateContinuousPutPricet(t, delta, R, B0, Bt) {
//     var decay = Math.exp(-new bignumber_js_1.BigNumber(delta).multipliedBy(new bignumber_js_1.BigNumber(t)).dividedBy(SECONDS_IN_A_YEAR)).toString();
//     var K = getK(B0, R);
//     var _Bt = getInt128(Bt);
//     var pbt = _Bt.lt(K) ? int128Mul(K.sub(_Bt), getInt128(decay)) : getInt128("0");
//     return pbt;
// }
// var rr = "2"; // R
// var t = "864000";
// var btcPrice0 = "60000"; // B0
// var btcPricet = "70000"; // Bt
// var data = ltable[0];
// var d = calculateContinuousPutPricet(t, data.delta, rr, btcPrice0, btcPricet);
// var Q0 = int128Div(getInt128("2"), d);
// var num = int128Mul(getInt128("2"), d).mul(99).div(100);
// var den = int128Mul(getRL(eta2, data.l3, data.l4), priceImpact(getRL(eta2, data.l3, data.l4).toString(), getInt128("2").toString(), d.toString())).add(UNIT64);
// console.log("Pt: " + d.toString(), int128ToDecimal(d.toString()) + "\n" +
//     "price impact:", priceImpact(getRL(eta2, data.l3, data.l4).toString(), getInt128("2").toString(), d.toString()).toString(), "\n", "Q:", int128Div(num, den).toString(), int128ToDecimal(int128Div(num, den).toString()), int128ToDecimal("1728492178778794409589028"));
// /*
// console.log(
//   "E:", getEP(data.l3, data.l4, rr, btcPrice0).toString(),  int128ToDecimal(getEP(data.l3, data.l4, rr, btcPrice0).toString()), "\n",
//   "P0:",  b.toString(), int128ToDecimal(b.toString()), "\n",
//   "Q:", Q0.toString(), "\n",
//   "P0:", int128ToDecimal("218027988341910379114220"),
// );
// */
// /*
// let a = calculateContinuousCallPrice0(data.l1, data.l2, rr, btcPrice0);
// let b = calculateContinuousPutPrice0(data.l3, data.l4, rr, btcPrice0);
// let c = calculateContinuousCallPricet("864000", data.delta, data.l1, data.l2, rr, btcPrice0, btcPricet);
// let d = calculateContinuousPutPricet("864000", data.delta, data.l3, data.l4, rr, btcPrice0, btcPricet);



// console.log(
//   new BN(a.toString()).dividedBy(UNIT64.toString()).toString(),
//   new BN(b.toString()).dividedBy(UNIT64.toString()).toString(),
//   new BN(c.toString()).dividedBy(UNIT64.toString()).toString(),
//   new BN(d.toString()).dividedBy(UNIT64.toString()).toString()
//   );

// let aB = calculatePrice0(eta1, data.l1, data.l2, rr);
// let bB = calculatePrice0(eta2, data.l3, data.l4, rr);
// let cB = calculateCallPricet("864000", data.delta, data.l1, data.l2, rr, btcPrice0, btcPricet);
// let dB = calculatePutPricet("864000", data.delta, data.l3, data.l4, rr, btcPrice0, btcPricet);

// console.log(
//   new BN(aB.toString()).dividedBy(UNIT64.toString()).toString(),
//   new BN(bB.toString()).dividedBy(UNIT64.toString()).toString(),
//   new BN(cB.toString()).dividedBy(UNIT64.toString()).toString(),
//   new BN(dB.toString()).dividedBy(UNIT64.toString()).toString()
//   );
// */
// /*

// console.log(new BN(getOmega(eta1, ltable[0].l1, ltable[0].l2).toString()).dividedBy(UNIT64.toString()).toString(),
//   new BN(getOmega(eta2, ltable[0].l3, ltable[0].l4).toString()).dividedBy(UNIT64.toString()).toString(),);

  
// console.log(
//   new BN(getOmega(eta1, ltable[0].l1, ltable[0].l2).toString()).dividedBy(UNIT64.toString()).toString(),
//   new BN(getOmega(eta2, ltable[0].l3, ltable[0].l4).toString()).dividedBy(UNIT64.toString()).toString(),
//   new BN(getEP(ltable[0].l3, ltable[0].l4).toString()).dividedBy(UNIT64.toString()).toString(), new BN(getFP(ltable[0].l3, ltable[0].l4, rr).toString()).dividedBy(UNIT64.toString()).toString()
//   );

//   */ 
