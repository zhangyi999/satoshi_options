const { expect } = require("chai");
const { constants, Contract, Wallet } = require('ethers');
const { ethers } = require("hardhat");

const BigNumber = require('bignumber.js');
const Web3 = require('web3');





const web3 = new Web3();
const abi = require('ethereumjs-abi');
// const walletPrivateKey = Wallet.fromMnemonic("0cc2cc4394407fbf1463d0f6099b97215f5f1e31b8d8784b8cb7c3b3252f7fbb")
const PRIVATE_KEY = "0cc2cc4394407fbf1463d0f6099b97215f5f1e31b8d8784b8cb7c3b3252f7fbb";  //2109

console.log(
  web3.eth.accounts.privateKeyToAccount(PRIVATE_KEY)
)

function getInt128(num) {
  let _num = (new BigNumber(num).multipliedBy(new BigNumber(2).pow(64))).toString(10);
  _num = _num.split('.')[0];
  // console.log("_num", _num);
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
  }
]
// CBBCRouter
let accounts, deployer, user, factory, tToken0;
let nonce = new BigNumber(0);
const cppcAddress = "0x4E88216b4174A3da5CDaC7D83A9D21F08A8b2109";
async function setupContracts() {
  accounts = await ethers.getSigners()
  deployer = accounts[0]
  user = accounts[1]

  const erc20Token = await ethers.getContractFactory("ERC20", deployer);
  // tToken0 = await erc20Token.deploy(TOTAL_SUPPLY);
  // factory = await (await ethers.getContractFactory("CbbcFactory", deployer)).deploy();
}


async function getPriceData(tokenAddress, tradePrice) {
  const nonce_ = nonce;
  nonce = nonce.plus(1);

  const parameterTypes = ["address", "uint256", "uint256", "address"];
  const parameterValues = [tokenAddress, tradePrice.toString(), nonce_.toString(), cppcAddress];
  const hash = "0x" + abi.soliditySHA3(parameterTypes, parameterValues).toString("hex");
  const signature_ = web3.eth.accounts.sign(hash, PRIVATE_KEY);

  return {
    tradePrice: tradePrice.toString(),
    nonce: nonce_.toString(),
    signature: signature_.signature
  };
}


describe("Greeter", function () {
  beforeEach("set up the contracts", setupContracts);


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
    console.log(LTable)
    let tx = await greeter.SetLTable(LTable);

    // let DeltaTable = await greeter.getDeltaTable(
    //   getInt128(ltable[0]["delta"])
    // );
    // console.log("DeltaTable--", DeltaTable);

    // let upOmg = await greeter.getUpOmg(
    //   getInt128(ltable[0]["delta"])
    // );
    // console.log("upOmg--", upOmg.toString());

    // let downOmg = await greeter.getDownOmg(
    //   getInt128(ltable[0]["delta"])
    // );
    // console.log("downOmg--", downOmg.toString())

    // let purchaseQuantity = await greeter.getPurchaseQuantity([
    //   true,// direction;
    //   getInt128(2),// bk;
    //   getInt128(ltable[0]["delta"]),// delta;
    //   getInt128(2)// _i;
    // ])
    // console.log("purchaseQuantity--", purchaseQuantity.toString())

    // let TB = await greeter.getTB(
    //   true,// direction;
    //   getInt128(60000)// K;
    // )
    // console.log("TB--", TB.toString())

    // let PBCT = await greeter.getPBCT([
    //   true,// direction;
    //   getInt128(ltable[0]["delta"]),// delta,
    //   getInt128(123456),// t,
    //   getInt128(2),// BK,
    // ]
    // )
    // console.log("PBCT--", PBCT.toString())

    // // let RL = await greeter.getRL([
    // //   true,// direction;
    // //   getInt128(ltable[0]["delta"]),// delta,
    // //   getInt128(2),// BK;
    // //   getInt128(60000), // K
    // // ]
    // // )
    // // console.log("RL--", RL.toString())

    // // let Priceimpact = await greeter.getPriceimpact([
    // //   "49149741625773706179",// rl;
    // //   "49149741625773706179",// pbct;
    // //   getInt128(2),// Q;
    // // ]
    // // )
    // // console.log("Priceimpact--", Priceimpact.toString())

    // // let LiquidationNum = await greeter.getLiquidationNum([
    // //   "49149741625773706179",// pbct;
    // //   getInt128(2),// Q;
    // //   "49149741625773706179",// rl;
    // //   getInt128(10591111237041),// priceimpact;
    // // ])
    // // console.log("LiquidationNum--", LiquidationNum.toString())

    // // 开仓

    // let _delta = getInt128(ltable[0]["delta"]);
    // console.log("开仓Delta", _delta);
    // let open = await greeter.open(
    //   true,// direction;
    //   getInt128(ltable[0]["delta"]),// delta;
    //   getInt128(2),// bk;
    //   getInt128(500),// cppcNum;
    // )
    // open.wait();
    // console.log("open--", open)

    // // 获取持仓
    // let NftDatas = await greeter.getNFT()
    // const pid = NftDatas[0].pid.toString()
    // const cppcNum = NftDatas[0].cppcNum.toString()
    // const createTime = NftDatas[0].createTime.toString()
    // console.log("NftDatas--", NftDatas, pid, cppcNum, createTime)

    // // 平仓

    // let withdraw = await greeter.Withdraw(
    //   pid,// direction;
    //   getInt128(86000),//btcPrice
    // )
    // // withdraw.wait();
    // console.log("withdraw--", withdraw)





    // // testPrice
    const tradeToken = "0x279F9ABfa3495ac679BAe22590d96777eF65D434";
    let signedPr = await getPriceData(tradeToken, ethers.utils.parseUnits('40000', 18));
    console.log("signedPr", signedPr);
    let checkIdentity = await greeter._checkIdentityAndUpdateOracle(
      tradeToken,
      signedPr,
    )
    // withdraw.wait();
    console.log("checkIdentity--", checkIdentity)

  });


});
