import { BigNumber as BN } from 'bignumber.js';
import { BigNumber } from "ethers";



function getInt128(num:string):BigNumber {
  let _num = (new BN(num).multipliedBy(new BN(2).pow(64))).toString(10);
  _num = _num.split('.')[0];
  // console.log("_num", _num);
  return BigNumber.from(_num);
}

function int128Div(a:BigNumber, b:BigNumber):BigNumber{
  let _c = BigNumber.from(2).pow(64);
  let _d = a.mul(_c).div(b);
  return BigNumber.from(_d.toString().split('.')[0]);
}

function int128Mul(a:BigNumber, b:BigNumber):BigNumber{
  let _c = BigNumber.from(2).pow(64);
  let _d = a.mul(b).div(_c);
  return BigNumber.from(_d.toString().split('.')[0]);
}

function int128ToDecimal(num:string):number{
  let _num:number = new BN(num).dividedBy(UNIT64.toString()).toNumber();
  return _num;
}

const MAX_UINT256 = BigNumber.from(2).pow(256).sub(1)
const UNIT64 = BigNumber.from(2).pow(64);
const SECONDS_IN_A_YEAR = 31536000;

const currBtc = 65000;
const depositFee = 0.01;
const withdrawFee = 0.01;
const r = 0.03;
const sigma = 1;
const lambda = 50.9684;
const eta1 = "21.51";
const eta2 = "24.15";
const p = "0.5645";
const q = "0.4355";
const phi = "0.00000036";
const pcpct = 0.01;
const ltable = [
  {
    delta: "2",
    l1: "2.365409217",
    l2: "24.2290085",
    l3: "1.424722727",
    l4: "25.841622"
  },
  {
    delta: "6",
    l1: "3.65446369",
    l2: "24.266891",
    l3: "4.032382035",
    l4: "25.90249482"
  },
  {
    delta: "8760",
    l1: "133.7577595",
    l2: "21.43795928",
    l3: "131.7684318",
    l4: "24.0887339"
  },
  {
    delta: "525600",
    l1: "1026.321008",
    l2: "21.50882215",
    l3: "1024.340376",
    l4: "24.14898351"
  }
]

function getOmega(eta1:string, L1:string, L2:string):BigNumber{
  let _eta1:BigNumber = getInt128(eta1);
  let _L1:BigNumber = getInt128(L1);
  let _L2:BigNumber = getInt128(L2);

  let omgc:BigNumber = int128Mul(int128Div(_eta1.sub(_L1), _eta1), int128Div(_L2, _L2.sub(_L1)));
  return omgc;
}

function calculatePrice0(eta:string, L1:string, L2:string, R:string):BigNumber{
  
  let omgc:BigNumber = getOmega(eta, L1, L2);
  let expExpression1:BigNumber = getInt128(Math.pow(new BN(R).toNumber(), new BN(L1).toNumber()).toString());
  let expExpression2:BigNumber = getInt128(Math.pow(new BN(R).toNumber(), new BN(L2).toNumber()).toString());


  let pb0:BigNumber = int128Div(omgc, expExpression1).add(int128Div(UNIT64.sub(omgc), expExpression2));
  
  return pb0;
}

function getK(B0:string, R:string):BigNumber{
  return int128Mul(getInt128(B0), getInt128(R));
}

function getRL(eta:string, L1:string, L2:string):BigNumber{
  let RL:string = new BN(L1).multipliedBy(L2).dividedBy(eta).toString();
  return getInt128(RL);
}

function priceImpact(RL:string, Q:string, pricet:string):BigNumber{
  let num: BigNumber = int128Mul(int128Mul(BigNumber.from(RL), BigNumber.from(Q)), BigNumber.from(pricet));
  let den: number = int128ToDecimal(num.toString());
  let result:string = new BN(phi).multipliedBy(Math.sqrt(den)).toString();
  return getInt128(result);
}

// t: seconds elapsed since the beginning of purchase
function calculateCallPricet(t:string, delta:string, L1:string, L2:string, R:string, B0:string,Bt:string): BigNumber{
  let decay: string = Math.exp(-new BN(delta).multipliedBy(new BN(t)).dividedBy(SECONDS_IN_A_YEAR)).toString();
  let omegaC:BigNumber = getOmega(eta1, L1, L2);
  let K:BigNumber = getK(B0, R);
  let _Bt = getInt128(Bt);
  let TB:BigNumber = K.gt(_Bt) ? _Bt : K;
  let TBK:BN = new BN(TB.toString()).dividedBy(new BN(K.toString()));
  let expExpression1:BigNumber = int128Mul(omegaC, getInt128(Math.pow(TBK.toNumber(), new BN(L1).toNumber()).toString()));
  let expExpression2:BigNumber = int128Mul(UNIT64.sub(omegaC), getInt128(Math.pow(TBK.toNumber(), new BN(L2).toNumber()).toString()));
  let pbt:BigNumber = int128Mul(expExpression1.add(expExpression2), getInt128(decay));

  return pbt;
}


function calculatePutPricet(t:string, delta:string, L3:string, L4:string, R:string, B0:string,Bt:string): BigNumber{
  let decay: string = Math.exp(-new BN(delta).multipliedBy(new BN(t)).dividedBy(SECONDS_IN_A_YEAR)).toString();
  let omegaC:BigNumber = getOmega(eta2, L3, L4);
  let K:BigNumber = getK(B0, R);
  let _Bt = getInt128(Bt);
  let TB:BigNumber = K.lt(_Bt) ? _Bt : K;
  let TBK:BN = new BN(TB.toString()).dividedBy(new BN(K.toString()));
  let expExpression1:BigNumber = int128Mul(omegaC, getInt128(Math.pow(TBK.toNumber(), -new BN(L3).toNumber()).toString()));
  let expExpression2:BigNumber = int128Mul(UNIT64.sub(omegaC), getInt128(Math.pow(TBK.toNumber(), -new BN(L4).toNumber()).toString()));
  let pbt:BigNumber = int128Mul(expExpression1.add(expExpression2), getInt128(decay));

  return pbt;
}


// calculate the price of the contiuous payoff option
function getEC(L1:string, L2:string, R:string, B0:string):BigNumber{
  let omgc:BigNumber = getOmega(eta1, L1, L2);
  let _L1:BigNumber = getInt128(L1);
  let _L2:BigNumber = getInt128(L2);

  let numerator:BigNumber = int128Mul(_L1, omgc).add(int128Mul(_L2, UNIT64.sub(omgc)));
  let denominator:BigNumber = int128Mul(_L1, omgc).add(int128Mul(_L2, UNIT64.sub(omgc))).sub(UNIT64);
  let K = getK(B0, R);

  return int128Div(int128Mul(numerator,K), denominator);
}


function getFC(L1:string, L2:string, R:string, B0:string):BigNumber{
  let omgc:BigNumber = getOmega(eta1, L1, L2);
  let Ec:BigNumber = getEC(L1, L2, R, B0);
  let Ecr:number = new BN(Ec.toString()).dividedBy(new BN(UNIT64.toString())).multipliedBy(new BN(R)).toNumber();

  let denominator1:number = Math.pow(Ecr, new BN(L1).toNumber());
  let denominator2:number = Math.pow(Ecr, new BN(L2).toNumber());

  let result:BigNumber = int128Div(omgc, getInt128(denominator1.toString())).add(int128Div(UNIT64.sub(omgc), getInt128(denominator2.toString())));

  return int128Mul(result, Ec.sub(UNIT64));
}

function calculateContinuousCallPrice0(L1:string, L2:string, R:string, B0:string):BigNumber{
  let K = getK(B0, R);
  let omgc:BigNumber = getOmega(eta1, L1, L2);
  let Ec:BigNumber = getEC(L1, L2, R, B0);
  let Ecr:number = new BN(getInt128(B0).toString()).dividedBy(Ec.toString()).toNumber();

  let denominator1:number = Math.pow(Ecr, new BN(L1).toNumber());
  let denominator2:number = Math.pow(Ecr, new BN(L2).toNumber());

  let result:BigNumber = int128Mul(omgc, getInt128(denominator1.toString())).add(int128Mul(UNIT64.sub(omgc), getInt128(denominator2.toString())));

  return int128Mul(result, Ec.sub(K));
}


// t: seconds elapsed since the beginning of purchase
/*
function calculateContinuousCallPricet(t:string, delta:string, L1:string, L2:string, R:string, B0:string, Bt:string): BigNumber{
  let decay: string = Math.exp(-new BN(delta).multipliedBy(new BN(t)).dividedBy(SECONDS_IN_A_YEAR)).toString();
  let omegaC:BigNumber = getOmega(eta1, L1, L2);
  let Ec:BigNumber = getEC(L1, L2, R, B0);
  let K:BigNumber = getK(B0, R);
  let _Bt = getInt128(Bt);
  let TBK:BN;
  let expExpression1:BigNumber;
  let expExpression2:BigNumber;
  let pbt:BigNumber;

  if(_Bt.gte(int128Mul(K, Ec))){
    return int128Mul(_Bt.sub(K), getInt128(decay));
  }else{
    TBK = new BN(int128Div(_Bt, int128Mul(K, Ec)).toString()).dividedBy(new BN(UNIT64.toString()));
    expExpression1 = int128Mul(omegaC, getInt128(Math.pow(TBK.toNumber(), new BN(L1).toNumber()).toString()));
    expExpression2 = int128Mul(UNIT64.sub(omegaC), getInt128(Math.pow(TBK.toNumber(), new BN(L2).toNumber()).toString()));
    pbt = int128Mul(int128Mul(expExpression1.add(expExpression2), Ec.sub(UNIT64)), int128Mul(getInt128(decay), K));

    return pbt;
  }

}
*/

function calculateContinuousCallPricet(t:string, delta:string, R:string, B0:string, Bt:string): BigNumber{
  let decay: string = Math.exp(-new BN(delta).multipliedBy(new BN(t)).dividedBy(SECONDS_IN_A_YEAR)).toString();
  let K:BigNumber = getK(B0, R);
  let _Bt = getInt128(Bt);
  let pbt:BigNumber = _Bt.gt(K) ? int128Mul(_Bt.sub(K), getInt128(decay)) : getInt128("0");
  
  return pbt;

}

function getEP(L3:string, L4:string, R:string, B0:string):BigNumber{
  let omgp:BigNumber = getOmega(eta2, L3, L4);
  let _L3:BigNumber = getInt128(L3);
  let _L4:BigNumber = getInt128(L4);
  let K:BigNumber = getK(B0, R);

  let numerator:BigNumber = int128Mul(_L3, omgp).add(int128Mul(_L4, UNIT64.sub(omgp)));
  let denominator:BigNumber = int128Mul(_L3, omgp).add(int128Mul(_L4, UNIT64.sub(omgp))).add(UNIT64);

  return int128Div(int128Mul(numerator, K), denominator);
}

/*
function getFP(L3:string, L4:string, R:string):BigNumber{
  let omgp:BigNumber = getOmega(eta2, L3, L4);
  let Ep:BigNumber = getEP(L3, L4);
  let Epr:number = new BN(Ep.toString()).dividedBy(new BN(UNIT64.toString())).multipliedBy(new BN(R)).toNumber();

  let denominator1:number = Math.pow(Epr, new BN(L3).toNumber());
  let denominator2:number = Math.pow(Epr, new BN(L4).toNumber());

  let result:BigNumber = int128Mul(omgp, getInt128(denominator1.toString())).add(int128Mul(UNIT64.sub(omgp), getInt128(denominator2.toString())));

  return int128Mul(result, UNIT64.sub(Ep));
}
*/

function calculateContinuousPutPrice0(L3:string, L4:string, R:string, B0:string):BigNumber{
  let K = getK(B0, R);
  let omgc:BigNumber = getOmega(eta2, L3, L4);
  let Ep:BigNumber = getEP(L3, L4, R, B0);
  let Epr:number = new BN(Ep.toString()).dividedBy(getInt128(B0).toString()).toNumber();

  let denominator1:number = Math.pow(Epr, new BN(L3).toNumber());
  let denominator2:number = Math.pow(Epr, new BN(L4).toNumber());

  let result:BigNumber = int128Mul(omgc, getInt128(denominator1.toString())).add(int128Mul(UNIT64.sub(omgc), getInt128(denominator2.toString())));

  return int128Mul(result, K.sub(Ep));
}

/*
function calculateContinuousPutPricet(t:string, delta:string, L3:string, L4:string, R:string, B0:string, Bt:string): BigNumber{
  let decay: string = Math.exp(-new BN(delta).multipliedBy(new BN(t)).dividedBy(SECONDS_IN_A_YEAR)).toString();
  let omegaP:BigNumber = getOmega(eta2, L3, L4);
  let Ep:BigNumber = getEP(L3, L4);
  let K:BigNumber = getK(B0, R);
  let _Bt = getInt128(Bt);
  let TBK:BN;
  let expExpression1:BigNumber;
  let expExpression2:BigNumber;
  let pbt:BigNumber;

  if(_Bt.lte(int128Mul(K, Ep))){
    return int128Mul(K.sub(_Bt), getInt128(decay));
  }else{
    TBK = new BN(int128Div(_Bt, int128Mul(K, Ep)).toString()).dividedBy(new BN(UNIT64.toString()));
    expExpression1 = int128Mul(omegaP, getInt128(Math.pow(TBK.toNumber(), -new BN(L3).toNumber()).toString()));
    expExpression2 = int128Mul(UNIT64.sub(omegaP), getInt128(Math.pow(TBK.toNumber(), -new BN(L4).toNumber()).toString()));
    pbt = int128Mul(int128Mul(expExpression1.add(expExpression2), UNIT64.sub(Ep)), int128Mul(getInt128(decay), K));

    return pbt;
  }

}
*/

function calculateContinuousPutPricet(t:string, delta:string, R:string, B0:string, Bt:string): BigNumber{
  let decay: string = Math.exp(-new BN(delta).multipliedBy(new BN(t)).dividedBy(SECONDS_IN_A_YEAR)).toString();
  let K:BigNumber = getK(B0, R);
  let _Bt = getInt128(Bt);
  let pbt:BigNumber = _Bt.lt(K) ? int128Mul(K.sub(_Bt), getInt128(decay)) : getInt128("0");
  
  return pbt;

}


let rr = "2"; // R
let t = "864000";
let btcPrice0 = "60000"; // B0
let btcPricet = "70000"; // Bt
let data = ltable[0];


let d = calculateContinuousPutPricet(t, data.delta, rr, btcPrice0, btcPricet);
let Q0 = int128Div(getInt128("2"), d);

let num = int128Mul(getInt128("2"), d).mul(99).div(100);
let den = int128Mul(getRL(eta2, data.l3, data.l4), priceImpact(getRL(eta2, data.l3, data.l4).toString(), getInt128("2").toString(), d.toString())).add(UNIT64);


console.log(
  "Pt: " + d.toString(), int128ToDecimal(d.toString()) + "\n" +
  "price impact:",  priceImpact(getRL(eta2, data.l3, data.l4).toString(), getInt128("2").toString(), d.toString()).toString(), "\n",
  "Q:", int128Div(num, den).toString(), int128ToDecimal(int128Div(num, den).toString()), int128ToDecimal("1728492178778794409589028")
);

/*
console.log(
  "E:", getEP(data.l3, data.l4, rr, btcPrice0).toString(),  int128ToDecimal(getEP(data.l3, data.l4, rr, btcPrice0).toString()), "\n",
  "P0:",  b.toString(), int128ToDecimal(b.toString()), "\n",
  "Q:", Q0.toString(), "\n",
  "P0:", int128ToDecimal("218027988341910379114220"),
);
*/


/*
let a = calculateContinuousCallPrice0(data.l1, data.l2, rr, btcPrice0);
let b = calculateContinuousPutPrice0(data.l3, data.l4, rr, btcPrice0);
let c = calculateContinuousCallPricet("864000", data.delta, data.l1, data.l2, rr, btcPrice0, btcPricet);
let d = calculateContinuousPutPricet("864000", data.delta, data.l3, data.l4, rr, btcPrice0, btcPricet);



console.log(
  new BN(a.toString()).dividedBy(UNIT64.toString()).toString(), 
  new BN(b.toString()).dividedBy(UNIT64.toString()).toString(), 
  new BN(c.toString()).dividedBy(UNIT64.toString()).toString(), 
  new BN(d.toString()).dividedBy(UNIT64.toString()).toString()
  );

let aB = calculatePrice0(eta1, data.l1, data.l2, rr);
let bB = calculatePrice0(eta2, data.l3, data.l4, rr);
let cB = calculateCallPricet("864000", data.delta, data.l1, data.l2, rr, btcPrice0, btcPricet);
let dB = calculatePutPricet("864000", data.delta, data.l3, data.l4, rr, btcPrice0, btcPricet);

console.log(
  new BN(aB.toString()).dividedBy(UNIT64.toString()).toString(), 
  new BN(bB.toString()).dividedBy(UNIT64.toString()).toString(), 
  new BN(cB.toString()).dividedBy(UNIT64.toString()).toString(), 
  new BN(dB.toString()).dividedBy(UNIT64.toString()).toString()
  );
*/



/*

console.log(new BN(getOmega(eta1, ltable[0].l1, ltable[0].l2).toString()).dividedBy(UNIT64.toString()).toString(),  
  new BN(getOmega(eta2, ltable[0].l3, ltable[0].l4).toString()).dividedBy(UNIT64.toString()).toString(),);

  
console.log(
  new BN(getOmega(eta1, ltable[0].l1, ltable[0].l2).toString()).dividedBy(UNIT64.toString()).toString(),  
  new BN(getOmega(eta2, ltable[0].l3, ltable[0].l4).toString()).dividedBy(UNIT64.toString()).toString(),
  new BN(getEP(ltable[0].l3, ltable[0].l4).toString()).dividedBy(UNIT64.toString()).toString(), new BN(getFP(ltable[0].l3, ltable[0].l4, rr).toString()).dividedBy(UNIT64.toString()).toString()
  );

  */