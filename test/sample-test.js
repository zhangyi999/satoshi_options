const { expect } = require("chai");
const { ethers } = require("hardhat");

const BigNumber = require('bignumber.js');
function getInt128(num) {
  let _num = (new BigNumber(num).multipliedBy(new BigNumber(2).pow(64))).toString(10);
  // console.log("_num", _num);
  return _num
}

describe("Greeter", function () {

  it("Should return the new greeting once it's changed", async function () {
    accounts = await ethers.getSigners();
    deployer = accounts[0];
    const Greeter = await ethers.getContractFactory("SatoshiOpstion");
    const greeter = await Greeter.deploy('cppcNft', 'cppc');
    await greeter.deployed();

    // greeter.
    expect(await greeter.SetConfig(
      getInt128(65000),
      getInt128(55000),
      getInt128(3),
      getInt128(3),
      getInt128(1),
      getInt128(50),
      getInt128(21),
      getInt128(24),
      getInt128(1),
      getInt128(1),
      getInt128(1),
      getInt128(10000000000),
    ));

    let tx = await greeter.SetLTable([[
      getInt128(1), //delta
      getInt128(2), //L1
      getInt128(3), //L2
      getInt128(3), //L3
      getInt128(3)//L4
    ]]
    );
    tx.wait()

    let upOmg = await greeter.getUpOmg(
      getInt128(2), //L1
      getInt128(3), //L2
    );
    console.log("upOmg--", upOmg.toString());
    let downOmg = await greeter.getUpOmg(
      getInt128(2), //L3
      getInt128(3), //L4
    );
    console.log("downOmg--", downOmg.toString())


    let purchaseQuantity = await greeter.getPurchaseQuantity([
      true,// direction;
      getInt128(2),// bk;
      getInt128(1),// delta;
      getInt128(2)// _i;
    ])
    console.log("purchaseQuantity--", purchaseQuantity.toString())

    let TB = await greeter.getTB(
      true,// direction;
      getInt128(2),// bk;
      getInt128(1),// delta;
    )
    console.log("TB--", TB.toString())

    // let PBCT = await greeter.getPBCT([
    //   true,// direction;
    //   getInt128(1),// delta,
    //   getInt128(1234),// t,
    //   getInt128(65000),// B,
    //   getInt128(62000),// K,
    //   getInt128(2),// l1Orl3,
    //   getInt128(3),// l2Orl4,
    //   getInt128(3), //omg
    // ]
    // )
    // console.log("PBCT--", PBCT.toString())

    // let RL = await greeter.getRL(true,[
    //   getInt128(65000),// B;
    //   getInt128(62000),// K,
    //   getInt128(2),// l1Orl3,
    //   getInt128(3),// l2Orl4,
    //   getInt128(3), //omg
    // ]
    // )
    // console.log("RL--", RL.toString())

    let Priceimpact = await greeter.getPriceimpact([
      getInt128(3),// lpha;
      getInt128(3),// delta,
      getInt128(5),// rl;
      getInt128(2),// Q;
      getInt128(2),// pbct;
    ]
    )
    console.log("Priceimpact--", Priceimpact.toString())

    let LiquidationNum = await greeter.getLiquidationNum([
      getInt128(2),// pbct;
      getInt128(2),// Q;
      getInt128(5),// rl;
      getInt128(5),// priceimpact;
    ]
    )
    console.log("LiquidationNum--", LiquidationNum.toString())
  });
});
