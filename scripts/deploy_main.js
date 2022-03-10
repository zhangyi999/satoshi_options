// const { expect } = require("chai");
// const { constants, Contract, Wallet } = require('ethers');
// const { ethers } = require("hardhat");

// const BigNumber = require('bignumber.js');
// const Web3 = require('web3');

// const { BigNumber: BN } = ethers

// // console.log(.toHexString())
// // cbbcRouterAddress: '0x52B307ccA4936F35AC850e212F6B94d1D0940A94',
// //       orchestratorAddress: '0xEF1B5eE21bC55592b30c8ed85eB66cAb67A8110D',
// //       marketOracleAddress: '0xC68A93B2BB86192B544456A24c6F6234A0961508',

// //       wethAddress: '0xd0a1e359811322d97991e03f863a0c30c2cf029c', // 注：就是结算币ETH的address（heco下就是HT的address）
// //       addressResolver: '0xfF46780c39C878B7f4aF4FB8029e8b01F7157f19',

// //       cppcChefAddress: '0x2F54904AD371235c135697fD78612808c3dFbbd3',
// const address = {
//     kov: {
//         charm: '0x8a10932A85dAc0b75BBb99EAc0A0334FF57B9Cd9',
//         router: '0x52B307ccA4936F35AC850e212F6B94d1D0940A94'
//     }
// }

// const ADDR = address['kov']

// const web3 = new Web3();
// const abi = require('ethereumjs-abi');
// // const walletPrivateKey = Wallet.fromMnemonic("0cc2cc4394407fbf1463d0f6099b97215f5f1e31b8d8784b8cb7c3b3252f7fbb")
// const PRIVATE_KEY = "0x1b502936fcfa1381d1bc454dac74f1a2d2c7e4ed7634fe1acc57b0fa32c5f26e";  //2109

// console.log(
//   web3.eth.accounts.privateKeyToAccount(PRIVATE_KEY)
// )

// function getInt128(num) {
//   let _num = (new BigNumber(num).multipliedBy(new BigNumber(2).pow(64))).toString(10);
//   _num = _num.split('.')[0];
//   // console.log("_num", _num);
//   return _num
// }
// const MAX_UINT256 = ethers.BigNumber.from(2).pow(256).sub(1)

// const currBtc = 60000;
// const depositFee = 0.01;
// const withdrawFee = 0.01;
// const r = 0.03;
// const sigma = 1;
// const lambda = 50.9684;
// const eta1 = 21.51;
// const eta2 = 24.15;
// const p = 0.5645;
// const q = 0.4355;
// const phi = 0.00000036;
// const pcpct = 0.01;
// const ltable = [
//   {
//     delta: "2",
//     l1: "2.365409217",
//     l2: "24.2290085",
//     l3: "1.424722727",
//     l4: "25.841622"
//   },
//   {
//     delta: "6",
//     l1: "3.65446369",
//     l2: "24.266891",
//     l3: "4.032382035",
//     l4: "25.90249482"
//   },
//   {
//     delta: "525600",
//     l1: "1026.321008",
//     l2: "21.50882215",
//     l3: "1024.340376",
//     l4: "24.14898351"
//   }
// ]
// // CBBCRouter
// let accounts, deployer, user, factory, tToken0;
// let nonce = new BigNumber(0);
// const SIGNER_ADDRESS = "0x9548B3682cD65D3265C92d5111a9782c86Ca886d"; //2109

// async function getPriceData(tokenAddress, tradePrice) {
//     const nonce_ = nonce;
//     nonce = nonce.plus(1);

//     const parameterTypes = ["address", "address", "int128", "uint256", "address"];
//     const parameterValues = [tokenAddress, tradePrice.toString(), nonce_.toString(), SIGNER_ADDRESS];
//     const hash = "0x" + abi.soliditySHA3(parameterTypes, parameterValues).toString("hex");
//     const signature_ = web3.eth.accounts.sign(hash, PRIVATE_KEY);

//     return {
//         tokenAddress,
//         tradePrice: tradePrice.toString(),
//         nonce: nonce_.toString(),
//         signature: signature_.signature
//     };
// }

// const DECIMALS = 18;
// const TOTAL_SUPPLY = ethers.utils.parseUnits('1000000', DECIMALS);
// let config;
// let SatoshiOpstion_Charm;
// let charm_token;

// async function main() {
//     //////// config ////////
//     // config = await ethers.getContractFactory("contracts/Config.sol:Config");
//     // config = await config.deploy();
//     // console.log("config address: ", config.address)

//     // let tx = await config.setConfig([
//     //     getInt128(depositFee),
//     //     getInt128(withdrawFee),
//     //     getInt128(sigma),
//     //     getInt128(lambda),
//     //     getInt128(eta1),
//     //     getInt128(eta2),
//     //     getInt128(p),
//     //     getInt128(q),
//     //     getInt128(phi),
//     //     getInt128(pcpct),
//     //     getInt128(r)
//     // ])
//     // console.log("set config hash: ",tx.hash)
//     // await tx.wait()

//     // tx = await config.setLTable(
//     //     ltable.map((item) => {
//     //         return [
//     //             getInt128(item.delta),
//     //             getInt128(item.l1),
//     //             getInt128(item.l2),
//     //             getInt128(item.l3),
//     //             getInt128(item.l4),
//     //         ]
//     //     })
//     // )
//     // console.log("set LTable hash: ",tx.hash)
//     // await tx.wait()

//     // //////// charm token ////////
//     // charm_token = await ethers.getContractFactory("Charm");
//     // // charm_token = await charm_token.deploy()
//     // charm_token = charm_token.attach(ADDR.charm)
//     // console.log("charm_token to: ", charm_token.address)

//     // //////// BinaryOptions & LinearOption ////////
//     // let BinaryOptions = await ethers.getContractFactory("BinaryOptions");

//     // BinaryOptions = await BinaryOptions.deploy()
//     // console.log('BinaryOptions tp: ', BinaryOptions.address)

//     // let LinearOptions = await ethers.getContractFactory("LinearOptions");
//     // LinearOptions = await LinearOptions.deploy()
//     // console.log('LinearOptions tp: ', LinearOptions.address)

//     // config address:  0xFB29cf3e321D6C52e5900ac62Bd07A72c4E5A65D
//     // set config hash:  0x732287f722e5371929fd0cbc173d7105999420f13e82b2485c338723eadff322
//     // set LTable hash:  0x053f60437262b481332a821b5522d7c836d9d2ee2149e6f15f9170d9c2e966a0
//     // charm_token to:  0x8a10932A85dAc0b75BBb99EAc0A0334FF57B9Cd9
//     // BinaryOptions to:  0x85656cF8451CeB81B0A48A03B82A0A0230bf1c28
//     // LinearOptions to:  0x3374822edb84D0645C64fDa075e15D1b3B721247
//     // SatoshiOptions_Charm to: 0x85656cF8451CeB81B0A48A03B82A0A0230bf1c28
//     //////// 线性期权 ////////
//     SatoshiOpstion_Charm = await ethers.getContractFactory("SatoshiOptions_Charm");
//     // SatoshiOpstion_Charm = await upgrades.deployProxy(SatoshiOpstion_Charm,[
//     //     'https://satoshiOpstion_sharm',
//     //     // config.address
//     //     '0xFB29cf3e321D6C52e5900ac62Bd07A72c4E5A65D'
//     // ]);
//     // console.log("SatoshiOpstion_Charm to: ", SatoshiOpstion_Charm.address)

//     SatoshiOpstion_Charm = SatoshiOpstion_Charm.attach('0x0D51Cb4bAc75F70cb294e6c006D5DD1eAc4b6D5A') 
//     tx = await SatoshiOpstion_Charm.setDataProvider(
//         '0xCDC15F917788E0cB7BB125F222B6124Fd8a6ef4C'
//     )
//     console.log("set siger hash: ",tx.hash)
//     await tx.wait()

//     // tx = await SatoshiOpstion_Charm.setStrategy(
//     //     // BinaryOptions.address
//     //     '0x85656cF8451CeB81B0A48A03B82A0A0230bf1c28'
//     // )
//     // console.log("setStrategy hash: ",tx.hash)
//     // await tx.wait()

//     // tx = await SatoshiOpstion_Charm.setStrategy(
//     //     // LinearOptions.address
//     //     '0x3374822edb84D0645C64fDa075e15D1b3B721247'
//     // )
//     // console.log("setStrategy hash: ",tx.hash)
//     // await tx.wait()

//     // tx = await SatoshiOpstion_Charm.setRoute(
//     //     ADDR.router
//     // )
//     // console.log("setRoute hash: ",tx.hash)
//     // await tx.wait()



//     // let [owner, alice, bob] = await ethers.getSigners()
//     // const mintAmount = BN.from(100000).mul('0x' + (1e18))
//     // tx = await charm_token.mint(owner.address, mintAmount)
//     // console.log('mint: ',tx.hash)
//     // await tx.wait()
// }

// // We recommend this pattern to be able to use async/await everywhere
// // and properly handle errors.
// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
