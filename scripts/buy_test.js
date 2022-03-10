// const { expect } = require("chai");
const { constants, Contract, Wallet } = require('ethers');
const { ethers } = require("hardhat");

const BigNumber = require('bignumber.js');
const Web3 = require('web3');

const { BigNumber: BN } = ethers

// console.log(.toHexString())
// cbbcRouterAddress: '0x52B307ccA4936F35AC850e212F6B94d1D0940A94',
//       orchestratorAddress: '0xEF1B5eE21bC55592b30c8ed85eB66cAb67A8110D',
//       marketOracleAddress: '0xC68A93B2BB86192B544456A24c6F6234A0961508',

//       wethAddress: '0xd0a1e359811322d97991e03f863a0c30c2cf029c', // 注：就是结算币ETH的address（heco下就是HT的address）
//       addressResolver: '0xfF46780c39C878B7f4aF4FB8029e8b01F7157f19',

//       cppcChefAddress: '0x2F54904AD371235c135697fD78612808c3dFbbd3',
const address = {
    kov: {
        charm: '0x8a10932A85dAc0b75BBb99EAc0A0334FF57B9Cd9',
        router: '0x52B307ccA4936F35AC850e212F6B94d1D0940A94'
    }
}

const ADDR = address['kov']

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
const MAX_HEX = '0x' + 'f'.repeat(64)

const currBtc = 60000;
const depositFee = 0.01;
const withdrawFee = 0.01;
const r = 0.03;
const sigma = 1;
const lambda = 50.9684;
const eta1 = 21.51;
const eta2 = 24.15;
const p = 0.5645;
const q = 0.4355;
const phi = 0.00000036;
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
    delta: "525600",
    l1: "1026.321008",
    l2: "21.50882215",
    l3: "1024.340376",
    l4: "24.14898351"
  }
]
// CBBCRouter
let accounts, deployer, user, factory, tToken0;
let nonce = new BigNumber(0);
const SIGNER_ADDRESS = "0x9548B3682cD65D3265C92d5111a9782c86Ca886d"; //2109

function getPriceData(tokenAddress, tradePrice, nonce) {
    const deadline = (new Date() / 1000 + 60).toFixed(0)
    const parameterTypes = ["address", "uint128", "uint256", "uint256", "address"];
    const parameterValues = [tokenAddress, tradePrice.toString(), nonce, deadline,SIGNER_ADDRESS];
    const hash = "0x" + abi.soliditySHA3(parameterTypes, parameterValues).toString("hex");
    const signature_ = web3.eth.accounts.sign(hash, PRIVATE_KEY);

    return {
        tokenAddress,
        tradePrice: tradePrice.toString(),
        nonce,
        deadline,
        signature: signature_.signature
    };
}

const DECIMALS = 18;
const TOTAL_SUPPLY = ethers.utils.parseUnits('1000000', DECIMALS);
let config;
let SatoshiOpstion_Charm;
let Charm;
let WETH;
let BTC;
let tx;
let router;

async function main() {
    //////// token /////////
    //////// token /////////
    // WETH = await ethers.getContractFactory("MockWETH");
    // WETH = await WETH.deploy();
    // console.log('WETH ', WETH.address)

    let TOKEN = await ethers.getContractFactory("Charm");
    // BTC = await TOKEN.deploy();
    BTC = TOKEN.attach('0x1d8E11b10e35AC2E355b39D8e0798D25Cd621837')
    console.log('BTC ', BTC.address)

    // Charm = await TOKEN.deploy();
    // console.log('Charm ', Charm.address)

    //////// config ////////
    // config = await ethers.getContractFactory("contracts/Config.sol:Config");
    // config = await config.deploy();
    // console.log("config address: ", config.address)

   

    //////// BinaryOptions & LinearOption ////////
    //////// 线性期权 ////////
    SatoshiOpstion_Charm = await ethers.getContractFactory("SatoshiOptions_Charm");
    // SatoshiOpstion_Charm = await upgrades.deployProxy(SatoshiOpstion_Charm,[
    //     'https://satoshiOpstion_sharm',
    //     // config.address
    //     config.address
    // ]);
    SatoshiOpstion_Charm = SatoshiOpstion_Charm.attach('0xa59d69290E9a9822F4C5Fe049572A391dA25bb06')
    console.log("SatoshiOpstion_Charm to: ", SatoshiOpstion_Charm.address)

    
    //////// router ////////
    router = await ethers.getContractFactory("Router");
    // router = await router.deploy(
    //     WETH.address,
    //     Charm.address,
    //     SatoshiOpstion_Charm.address
    // )
    router = router.attach('0x34E248C842354669E38532Ec5d9c906c5018B54E')

    console.log("router to ",router.address)

    const [owner, bob, alice, eln] = await ethers.getSigners();
    // tx = await BTC.mint(owner.address, '0xffffffffffffffffffffff')
    // await tx.wait()
    // tx = await BTC.mint('0xC0bE234aA298e132dAe278CC7ddD659270F386E2', '0xfffffffffffffffffffffffff')
    // await tx.wait() 
    // console.log(
    //     owner.address,'owner'
    // )
    tx = await BTC.approve(router.address, MAX_HEX)
    await tx.wait()
    console.log(getInt128(1123.31),'getInt128(1123.31)getInt128(1123.31)')
    const {
        tokenAddress,
        tradePrice,
        nonce,
        deadline,
        signature
    } = getPriceData('0x1d8E11b10e35AC2E355b39D8e0798D25Cd621837', getInt128(40000.31), 1 )
    // console.log(
    //     {
    //         tokenAddress,
    //         tradePrice,
    //         nonce,
    //         deadline,
    //         signature
    //     }
    // )
    const n = await SatoshiOpstion_Charm.seenNonces(SIGNER_ADDRESS)
        console.log(n,'n')
    console.log(
        false, // true 开多，false 看空
        getInt128(6), // delta
        getInt128(1.05), // 杠杆
        getInt128(1), // 金额
        '0x0E800AD36C24C5C63Ce6aBFc4eBacFbedE268B9b',
    )
    tx = await router.buyOptions(
        false, // true 开多，false 看空
        getInt128(6), // delta
        getInt128(1.05), // 杠杆
        getInt128(1), // 金额
        '0xEd95A8a9421AbBC5474a922bF6736C37292aF68C', // 策略 合约地址 ：contracts/public/BinaryOptions.sol | contracts/public/LinearOption.sol
        [
            tokenAddress, // 标的币种
            tradePrice, // 交易价格
            nonce, // 签名 有效 nonce
            deadline,
            signature // 签名
        ]
    )
    console.log(tx.hash)
    await tx.wait()

    // WETH  0xF79F435589c222eAc898cda06067De9733eD1254
    // BTC  0x21Fec888ec03F2816D56b816B874E7C3C9C90E45
    // Charm  0x26EDC6fCcf79fCe2aa468719767f3cB763088dd5
    // config address:  0xDbaB9EDb3B028B32522a720F1B57628BbC8A8e4d
    // addTokenDelta hash:  0xb96fa57c4d23ba1fc56893e018ae680334f5fd84358267437cc93c0b207968bb
    // BinaryOptions tp:  0x6be9AFfA469B84c9DF6B63c88Db07DB8df13D929
    // LinearOptions tp:  0x0E800AD36C24C5C63Ce6aBFc4eBacFbedE268B9b
    // SatoshiOpstion_Charm to:  0x05b340B04Bea6740119A7e181887fb479FfEEaEF
    // router to  0xc66c8b2920f3757D9443fcb52E6c2A4377194aef
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
