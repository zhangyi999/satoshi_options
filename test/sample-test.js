const { expect } = require("chai");
const { constants, Contract, Wallet } = require('ethers');
const { ethers } = require("hardhat");

const BigNumber = require('bignumber.js');
const Web3 = require('web3');

const {BigNumber:BN} = ethers

// console.log(.toHexString())




const web3 = new Web3();
const abi = require('ethereumjs-abi');
// const walletPrivateKey = Wallet.fromMnemonic("0cc2cc4394407fbf1463d0f6099b97215f5f1e31b8d8784b8cb7c3b3252f7fbb")
const PRIVATE_KEY = "0x1b502936fcfa1381d1bc454dac74f1a2d2c7e4ed7634fe1acc57b0fa32c5f26e";  //2109

console.log(
  web3.eth.accounts.privateKeyToAccount(PRIVATE_KEY)
)

function getInt128(num) {
  let _num = (new BigNumber(num).multipliedBy(new BigNumber(2).pow(64))).toString(10);
  _num = _num.split('.')[0];
  // console.log("_num", _num);
  return _num
}
const MAX_UINT256 = ethers.BigNumber.from(2).pow(256).sub(1)

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
const cppcAddress = "0x9548B3682cD65D3265C92d5111a9782c86Ca886d"; //2109
async function setupContracts() {
  accounts = await ethers.getSigners()
  deployer = accounts[0]
  user = accounts[1]
  // console.log("user", user)

  const cppcToken = await ethers.getContractFactory("contracts/Cppc.sol:Cppc");
  // console.log("cppcToken", cppcToken)
  // tToken0 = await erc20Token.deploy(TOTAL_SUPPLY);
  // factory = await (await ethers.getContractFactory("CbbcFactory", deployer)).deploy();

  // const cppcToken = await ethers.getContractFactory("Cppc", deployer);
  tToken0 = await cppcToken.deploy();
  console.log("tToken0.address", tToken0.address);

  await tToken0.deployed();
  let tx = await tToken0.mint(user.address, BN.from(100000).mul('0x'+(1e18).toString(16)));
  await tx.wait()
  // const _b = await user.getBalance()
  // console.log("_b", _b.toString());
}


async function getPriceData(tokenAddress, tradePrice) {
  const nonce_ = nonce;
  nonce = nonce.plus(1);

  const parameterTypes = ["address", "int128", "uint256", "address"];
  const parameterValues = [tokenAddress, tradePrice.toString(), nonce_.toString(), cppcAddress];
  const hash = "0x" + abi.soliditySHA3(parameterTypes, parameterValues).toString("hex");
  const signature_ = web3.eth.accounts.sign(hash, PRIVATE_KEY);

  return {
    tradePrice: tradePrice.toString(),
    nonce: nonce_.toString(),
    signature: signature_.signature
  };
}

const DECIMALS = 18;
const TOTAL_SUPPLY = ethers.utils.parseUnits('1000000', DECIMALS);
describe("Greeter", function () {
  beforeEach("set up the contracts", async function () {
    setupContracts();

  });


  it("Should return the new greeting once it's changed", async function () {
    accounts = await ethers.getSigners();
    deployer = accounts[0];
    // console.log("accounts", deployer);
    const Greeter = await ethers.getContractFactory("SatoshiOpstion");
    const greeter = await Greeter.deploy('cppcNft', 'cppc');
    await greeter.deployed();
    console.log("setCppc--start")
    await greeter.setCppc(tToken0.address);
    console.log("CppcAddress--", tToken0.address)
    console.log("setCppc--end")
    // console.log("greeter.address", greeter.address)
    const _tToken0B = await tToken0.balanceOf(user.address)
    console.log("CppcAddress--Balance", _tToken0B.toString());
    let tToken0Approve = await tToken0.connect(user).approve(greeter.address, MAX_UINT256);
    await tToken0Approve.wait()
    // greeter.
    let tx = await await greeter.SetConfig(
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
    )
    await tx.wait()

    const LTable = ltable.map((item) => {
      return [
        getInt128(item.delta),
        getInt128(item.l1),
        getInt128(item.l2),
        getInt128(item.l3),
        getInt128(item.l4),
      ]
    })
    // console.log(LTable)
    tx = await greeter.SetLTable(LTable);

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


    // 设置BTC价格
    const tradeToken = "0x279F9ABfa3495ac679BAe22590d96777eF65D434";
    let signedPr = await getPriceData(tradeToken, getInt128(65000));
    // console.log("signedPr", signedPr);
    // let checkIdentity = await greeter._checkIdentity(
    //   tradeToken,
    //   signedPr,
    // )
    // // withdraw.wait();
    // console.log("checkIdentity--", checkIdentity)


    // 开仓
    let _delta = getInt128(ltable[0]["delta"]);
    console.log("开仓Delta", _delta);

    let open = await greeter.connect(user).open(
      true,// direction;
      getInt128(ltable[0]["delta"]),// delta;
      getInt128(2),// bk;
      getInt128(500),// cppcNum;
      tradeToken,
      signedPr
    )
    open.wait();
    // console.log("open--", open)

    // 获取持仓
    let NftDatas = await greeter.getNFT()
    const pid = NftDatas[0].pid.toString()
    const cppcNum = NftDatas[0].cppcNum.toString()
    const createTime = NftDatas[0].createTime.toString()
    // console.log("NftDatas--", NftDatas, pid, cppcNum, createTime)

    // 平仓

    let withdraw = await greeter.connect(user).Withdraw(
      pid,// direction;
      getInt128(86000),//btcPrice
    )
    // withdraw.wait();
    console.log("withdraw--", withdraw)







  });


});
