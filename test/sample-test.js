const { expect } = require("chai");
const { ethers } = require("hardhat");

const BigNumber = require('bignumber.js');
function getInt128(num) {
  let _num = (new BigNumber(num).multipliedBy(new BigNumber(2).pow(64))).toString(10);
  _num = _num.split('.')[0];
  console.log("_num", _num);
  return _num
}
const currBtc = 65000;
const depositFee = 0.01;
const withdrawFee = 0.01;
const r = 0.03;
const sigma = 1;
const lambda = 50.9684;
const eta1 = 21.51;
const eta2 = 24.15;
const p = 0.5645;
const q = 0.4355;
const phi = 0.00000015;
const pcpct = 0.01;
const ltable = [
  {
    delta: "2.000000001",
    l1: "2.365409217",
    l2: "24.2290085",
    l3: "1.424722727",
    l4: "25.841622"
  },
  {
    delta: "6.000000009",
    l1: "3.65446369",
    l2: "24.266891",
    l3: "4.032382035",
    l4: "25.90249482"
  }
]

describe("Greeter", function () {

  it("Should return the new greeting once it's changed", async function () {
    accounts = await ethers.getSigners();
    deployer = accounts[0];
    const Greeter = await ethers.getContractFactory("SatoshiOpstion");
    const greeter = await Greeter.deploy('cppcNft', 'cppc');
    await greeter.deployed();

    // greeter.
    expect(await greeter.SetConfig(
      getInt128(currBtc),
      getInt128(depositFee),
      getInt128(withdrawFee),
      getInt128(sigma),
      getInt128(lambda),
      getInt128(eta1),
      getInt128(eta2),
      getInt128(p),
      getInt128(q),
      getInt128(phi),
      getInt128(pcpct),
      getInt128(r),
      // getInt128(10000000000),
    ));

    const LTable = ltable.map((item) => {
      return [
        getInt128(item.delta),
        getInt128(item.l1),
        getInt128(item.l2),
        getInt128(item.l3),
        getInt128(item.l4),
      ]
    })
    let tx = await greeter.SetLTable(LTable);

    // let DeltaTable = await greeter.getDeltaTable(
    //   getInt128(ltable[0]["delta"])
    // );
    // console.log("DeltaTable--", DeltaTable);

    let upOmg = await greeter.getUpOmg(
      getInt128(ltable[0]["delta"])
    );
    console.log("upOmg--", upOmg.toString());

    let downOmg = await greeter.getDownOmg(
      getInt128(ltable[0]["delta"])
    );
    console.log("downOmg--", downOmg.toString())

    let purchaseQuantity = await greeter.getPurchaseQuantity([
      true,// direction;
      getInt128(2),// bk;
      getInt128(ltable[0]["delta"]),// delta;
      getInt128(2)// _i;
    ])
    console.log("purchaseQuantity--", purchaseQuantity.toString())

    let TB = await greeter.getTB(
      true,// direction;
      getInt128(2)// bk;
    )
    console.log("TB--", TB.toString())

    // let PBCT = await greeter.getPBCT([
    //   true,// direction;
    //   getInt128(ltable[0]["delta"]),// delta,
    //   getInt128(123456),// t,
    //   getInt128(2),// BK,
    // ]
    // )
    // console.log("PBCT--", PBCT.toString())

    let RL = await greeter.getRL(true, [
      true,// direction;
      getInt128(ltable[0]["delta"]),// delta,
      getInt128(2),// BK;
    ]
    )
    console.log("RL--", RL.toString())

    let Priceimpact = await greeter.getPriceimpact([
      "49149741625773706179",// rl;
      "49149741625773706179",// pbct;
      getInt128(2),// Q;
    ]
    )
    console.log("Priceimpact--", Priceimpact.toString())

    let LiquidationNum = await greeter.getLiquidationNum([
      "49149741625773706179",// pbct;
      getInt128(2),// Q;
      "49149741625773706179",// rl;
      getInt128(10591111237041),// priceimpact;
    ])
    console.log("LiquidationNum--", LiquidationNum.toString())
  });
});
