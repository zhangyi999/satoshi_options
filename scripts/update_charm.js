// const { expect } = require("chai");
// const { constants, Contract, Wallet } = require('ethers');
// const { ethers } = require("hardhat");

// const BigNumber = require('bignumber.js');
// const Web3 = require('web3');

// const { BigNumber: BN } = ethers

// // console.log(.toHexString())

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
//     let [owner, alice, bob] = await ethers.getSigners()
//     SatoshiOpstion_Charm = await ethers.getContractFactory("SatoshiOptions_Charm");
//     SatoshiOpstion_Charm = await upgrades.upgradeProxy('0x67cABa39b375aAb0615442a8D799bC1aeB59e082',SatoshiOpstion_Charm);
//     console.log("SatoshiOpstion_Charm to: ", SatoshiOpstion_Charm.address)
// }

// // We recommend this pattern to be able to use async/await everywhere
// // and properly handle errors.
// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
