const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Greeter", function () {
  it("Should return the new greeting once it's changed", async function () {
    const Greeter = await ethers.getContractFactory("Greeter");
    const greeter = await Greeter.deploy("Hello, world!");
    await greeter.deployed();

    // greeter.
    expect(await greeter.SetConfig(
      65000 * 2 ** 64,
      55000 * 2 ** 64,
      0.3 * 2 ** 64,
      0.3 * 2 ** 64,
      1 * 2 ** 64,
      50.9686 * 2 ** 64,
      21.51 * 2 ** 64,
      24.15 * 2 ** 64,
      0.5645 * 2 ** 64,
      0.4355 * 2 ** 64,
      0.01 * 2 ** 64,
      10000000000 * 2 ** 64
    )).to.equal("SetConfig!");

    expect(await greeter.SetLTable([
      1 * 2 ** 64, //delta
      2 * 2 ** 64, //L1
      2 * 2 ** 64, //L2
      3 * 2 ** 64, //L3
      3 * 2 ** 64,//L4
    ]
    )).to.equal("SetLTable!");

    expect(await greeter.getUpOmg([
      2 * 2 ** 64, //L1
      2 * 2 ** 64, //L2
    ]
    )).to.equal("getUpOmg!");

    expect(await greeter.getDownOmg([
      2 * 2 ** 64, //L3
      2 * 2 ** 64, //L4
    ]
    )).to.equal("getDownOmg!");

    expect(await greeter.getPurchaseQuantity([
      true,// direction;
      2 * 2 ** 64,// bk;
      2 * 2 ** 64,// delta;
      2 * 2 ** 64// _i;
    ]
    )).to.equal("getPurchaseQuantity!");

    expect(await greeter.getTB([
      true,// direction;
      2 * 2 ** 64,// bk;
      3 * 2 ** 64,// delta;
    ]
    )).to.equal("getTB!");

    expect(await greeter.getPBCT([
      true,// direction;
      3 * 2 ** 64,// delta,
      1234 * 2 ** 64,// t,
      65000 * 2 ** 64,// B,
      62000 * 2 ** 64,// K,
      2 * 2 ** 64,// l1Orl3,
      2 * 2 ** 64,// l2Orl4,
      2 * 2 ** 64, //omg
    ]
    )).to.equal("getPBCT!");

    expect(await greeter.getRL([
      65000 * 2 ** 64,// B;
      62000 * 2 ** 64,// K;
      2 * 2 ** 64,// l1Orl3,
      2 * 2 ** 64,// l2Orl4,
      2 * 2 ** 64, //omg
    ]
    )).to.equal("getRL!");

    expect(await greeter.getPriceimpact([
      3 * 2 ** 64,// lpha;
      3 * 2 ** 64,// delta,
      5 * 2 ** 64,// rl;
      2 * 2 ** 64,// Q;
      2 * 2 ** 64,// pbct;
    ]
    )).to.equal("getPriceimpact!");

    expect(await greeter.getLiquidationNum([
      2 * 2 ** 64,// pbct;
      2 * 2 ** 64,// Q;
      5 * 2 ** 64,// rl;
      5 * 2 ** 64,// priceimpact;
    ]
    )).to.equal("getLiquidationNum!");



    // expect(await greeter.greet()).to.equal("Hello, world!");

    // const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

    // // wait until the transaction is mined
    // await setGreetingTx.wait();




    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });
});
