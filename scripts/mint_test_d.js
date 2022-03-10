// 0xC0bE234aA298e132dAe278CC7ddD659270F386E2

// const { expect } = require("chai");
// const { constants, Contract, Wallet } = require('ethers');
const { ethers } = require("hardhat");


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

    let TOKEN = await ethers.getContractFactory("Charm");
    BTC = TOKEN.attach('0x9AE5f3BA7Dbe484A91058ec22875857a2fa9F573');
    console.log('BTC ', BTC.address)

    tx = await BTC.mint('0xC0bE234aA298e132dAe278CC7ddD659270F386E2', '0xfffffffffffffffffffffffff')
    await tx.wait()    

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


//   WETH  0xF79F435589c222eAc898cda06067De9733eD1254
// BTC  0x21Fec888ec03F2816D56b816B874E7C3C9C90E45
// Charm  0x26EDC6fCcf79fCe2aa468719767f3cB763088dd5
// config address:  0xDbaB9EDb3B028B32522a720F1B57628BbC8A8e4d
// set config hash:  0xf38d4deaffd4f87b6152e291d1c0c21570f05fe4716fe23cc2572a693dfd45b0
// set LTable hash:  0x1fd8c65c80b79a7f334c391b685ba80c86842b6ee36feca6b543df4f047b0b28
// addTokenDelta hash:  0xb96fa57c4d23ba1fc56893e018ae680334f5fd84358267437cc93c0b207968bb
// BinaryOptions tp:  0x6be9AFfA469B84c9DF6B63c88Db07DB8df13D929
// LinearOptions tp:  0x0E800AD36C24C5C63Ce6aBFc4eBacFbedE268B9b
// SatoshiOpstion_Charm to:  0x05b340B04Bea6740119A7e181887fb479FfEEaEF
// set siger hash:  0x9973a4ae1defc57ae496a66c67addc5f7cf666514368b0f8365e1919cd85aa8c
// setStrategy hash:  0x6b6210f8027be928b1ffefeb64342ff30a2fcb9d2a71e29fbe8541f886192106
// setStrategy hash:  0xbbac15d9bb1deba57044f0d7a8ecdd60520864a4ac36aa24fcd96811471eff5f
// router to  0xc66c8b2920f3757D9443fcb52E6c2A4377194aef
// setRoute hash:  0x953b6d463d04f53085bcdb1920920347a5bccaecd8b7e78369cc283d93900977
// setupMinterRole hash:  0xa4db99ee94d7dee778379a9d2794bd0fb5fc1892af4270e57c19bc0ad626bf79