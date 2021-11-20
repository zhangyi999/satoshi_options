const { expect } = require("chai");
const { ethers } = require("hardhat");

const BigNumber = require('bignumber.js');
function getInt128(num) {
  let _num = (new BigNumber(num).multipliedBy(new BigNumber(2).pow(64))).toString(10);
  console.log("_num", _num);
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
    // expect(await greeter.SetConfig(
    //   (new BigNumber(65000).multipliedBy(new BigNumber(2).pow(64))).toString(10),
    //   (new BigNumber(55000).multipliedBy(new BigNumber(2).pow(64))).toString(10),
    //   (new BigNumber(3).multipliedBy(new BigNumber(2).pow(64))).toString(10),
    //   (new BigNumber(3).multipliedBy(new BigNumber(2).pow(64))).toString(10),
    //   (new BigNumber(1).multipliedBy(new BigNumber(2).pow(64))).toString(10),
    //   (new BigNumber(50).multipliedBy(new BigNumber(2).pow(64))).toString(10),
    //   (new BigNumber(21).multipliedBy(new BigNumber(2).pow(64))).toString(10),
    //   (new BigNumber(24).multipliedBy(new BigNumber(2).pow(64))).toString(10),
    //   (new BigNumber(1).multipliedBy(new BigNumber(2).pow(64))).toString(10),
    //   (new BigNumber(1).multipliedBy(new BigNumber(2).pow(64))).toString(10),
    //   (new BigNumber(1).multipliedBy(new BigNumber(2).pow(64))).toString(10),
    //   (new BigNumber(10000000000).multipliedBy(new BigNumber(2).pow(64))).toString(10),
    // ));

    let tx = await greeter.SetLTable([
      [
        getInt128(1), //delta
        getInt128(2), //L1
        getInt128(3), //L2
        getInt128(3), //L3
        getInt128(3)//L4
      ]
    ]
    );
    tx.wait()

    // getInt128(1), //delta
    //   getInt128(2), //L1
    //   getInt128(3), //L2
    //   getInt128(3), //L3
    //   getInt128(3)

    // expect(await greeter.getUpOmg([
    //   2 * 2 ** 64, //L1
    //   2 * 2 ** 64, //L2
    // ]
    // )).to.equal("getUpOmg!");

    // expect(await greeter.getDownOmg([
    //   2 * 2 ** 64, //L3
    //   2 * 2 ** 64, //L4
    // ]
    // )).to.equal("getDownOmg!");

    // expect(await greeter.getPurchaseQuantity([
    //   true,// direction;
    //   2 * 2 ** 64,// bk;
    //   2 * 2 ** 64,// delta;
    //   2 * 2 ** 64// _i;
    // ]
    // )).to.equal("getPurchaseQuantity!");

    // expect(await greeter.getTB([
    //   true,// direction;
    //   2 * 2 ** 64,// bk;
    //   3 * 2 ** 64,// delta;
    // ]
    // )).to.equal("getTB!");

    // expect(await greeter.getPBCT([
    //   true,// direction;
    //   3 * 2 ** 64,// delta,
    //   1234 * 2 ** 64,// t,
    //   65000 * 2 ** 64,// B,
    //   62000 * 2 ** 64,// K,
    //   2 * 2 ** 64,// l1Orl3,
    //   2 * 2 ** 64,// l2Orl4,
    //   2 * 2 ** 64, //omg
    // ]
    // )).to.equal("getPBCT!");

    // expect(await greeter.getRL([
    //   65000 * 2 ** 64,// B;
    //   62000 * 2 ** 64,// K;
    //   2 * 2 ** 64,// l1Orl3,
    //   2 * 2 ** 64,// l2Orl4,
    //   2 * 2 ** 64, //omg
    // ]
    // )).to.equal("getRL!");

    // expect(await greeter.getPriceimpact([
    //   3 * 2 ** 64,// lpha;
    //   3 * 2 ** 64,// delta,
    //   5 * 2 ** 64,// rl;
    //   2 * 2 ** 64,// Q;
    //   2 * 2 ** 64,// pbct;
    // ]
    // )).to.equal("getPriceimpact!");

    // expect(await greeter.getLiquidationNum([
    //   2 * 2 ** 64,// pbct;
    //   2 * 2 ** 64,// Q;
    //   5 * 2 ** 64,// rl;
    //   5 * 2 ** 64,// priceimpact;
    // ]
    // )).to.equal("getLiquidationNum!");
  });
});
