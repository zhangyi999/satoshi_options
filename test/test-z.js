const { expect } = require("chai");
const { constants, Contract, Wallet } = require('ethers');
const { ethers } = require("hardhat");

const BigNumber = require('bignumber.js');
const Web3 = require('web3');

const { BigNumber: BN } = ethers

// console.log(.toHexString())




const web3 = new Web3();
const abi = require('ethereumjs-abi');
// const walletPrivateKey = Wallet.fromMnemonic("0cc2cc4394407fbf1463d0f6099b97215f5f1e31b8d8784b8cb7c3b3252f7fbb")
const PRIVATE_KEY = "0x1b502936fcfa1381d1bc454dac74f1a2d2c7e4ed7634fe1acc57b0fa32c5f26e";  //2109


function getInt128(num) {
    let _num = (new BigNumber(num).multipliedBy(new BigNumber(2).pow(64))).toString(10);
    _num = _num.split('.')[0];
    // console.log("_num", _num);
    return _num
}
const MAX_UINT256 = '0x'+'f'.repeat(64)
const DECIMALS_HEX = '0X' + (1e18).toString(16)

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

// show string
function getNumForBig(big) {
    if ( big instanceof BigNumber ) {
        return big.toString(10)
    }

    if ( big instanceof BN ) {
        return big.toString()
    }

    if (  big instanceof Object ) {
        let obj = big instanceof Array ?[]:{}
        for(let k in big ) {
            obj[k] = getNumForBig(big[k])
        }
        return obj
    }
    return big
}

// CBBCRouter
let accounts, deployer, user, factory, tToken0;
const web3 = new Web3();
const abi = require('ethereumjs-abi');
const PRIVATE_KEY = "0x1b502936fcfa1381d1bc454dac74f1a2d2c7e4ed7634fe1acc57b0fa32c5f26e";  
let nonce = new BigNumber(0);
const SIGNER_ADDRESS = web3.eth.accounts.privateKeyToAccount(PRIVATE_KEY).address; //2109


function getPriceData(tokenAddress, tradePrice) {
    const nonce_ = nonce;
    nonce = nonce.plus(1);

    const parameterTypes = ["address", "uint128", "uint256", "address"];
    const parameterValues = [tokenAddress, tradePrice.toString(), nonce_.toString(), SIGNER_ADDRESS];
    const hash = "0x" + abi.soliditySHA3(parameterTypes, parameterValues).toString("hex");
    const signature_ = web3.eth.accounts.sign(hash, PRIVATE_KEY);

    return {
        tokenAddress,
        tradePrice: tradePrice.toString(),
        nonce: nonce_.toString(),
        signature: signature_.signature
    };
}

const DECIMALS = 18;
const TOTAL_SUPPLY = ethers.utils.parseUnits('1000000', DECIMALS);
let config;
let SatoshiOpstion_Charm;
let charm_token;
describe("SatoshiOpstion_Charm", function () {
    before("set up the contracts", async function () {
        //////// config ////////
        config = await ethers.getContractFactory("contracts/Config.sol:Config");
        config = await config.deploy();
        console.log("config address: ", config.address)

        let tx = await config.setConfig([
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
            getInt128(r)
        ])
        console.log("set config hash: ",tx.hash)
        await tx.wait()

        tx = await config.setLTable(
            ltable.map((item) => {
                return [
                    getInt128(item.delta), // getInt128(ltable[0].delta)
                    getInt128(item.l1),
                    getInt128(item.l2),
                    getInt128(item.l3),
                    getInt128(item.l4),
                ]
            })
        )
        console.log("set LTable hash: ",tx.hash)
        await tx.wait()

        //////// charm token ////////
        charm_token = await ethers.getContractFactory("Charm");
        charm_token = await charm_token.deploy()
        console.log("charm_token to: ", charm_token.address)

        //////// 线性期权 ////////
        SatoshiOpstion_Charm = await ethers.getContractFactory("SatoshiOpstion_Charm");
        SatoshiOpstion_Charm = await upgrades.deployProxy(SatoshiOpstion_Charm,[
            'http://satoshiOpstion_sharm',
            charm_token.address,
            config.address
        ]);
        console.log("SatoshiOpstion_Charm to: ", SatoshiOpstion_Charm.address)

        tx = await SatoshiOpstion_Charm.setDataProvider(
            SIGNER_ADDRESS
        )
        console.log("set siger hash: ",tx.hash)
        await tx.wait()

        //////// set burn ////////
        tx = await charm_token.setupMinterRole(SatoshiOpstion_Charm.address)
        await tx.wait()

    });

    // it("config", async function () {
    //     console.log(
    //         await SatoshiOpstion_Charm.config(),
    //         await config.delta(getInt128(ltable[0].delta))
    //     )
    //     console.log(
    //         await SatoshiOpstion_Charm.getDeltaTable(getInt128(ltable[0].delta))
    //     )
    // })

    it("mint charm", async function() {
        let [owner, alice, bob] = await ethers.getSigners()
        const mintAmount = BN.from(1000000).mul(DECIMALS_HEX)
        // const mintAmount = getNumForBig(new BigNumber(1000000).multipliedBy(DECIMALS_HEX))
        
        let tx = await charm_token.mint(owner.address, mintAmount)
        await tx.wait()
        
        tx = await charm_token.mint(alice.address, mintAmount)
        await tx.wait()
        tx = await charm_token.mint(bob.address, mintAmount)
        await tx.wait()
    })

    it ("signer", async () => {
        const tokenAddress = charm_token.address
        const tradePrice = '1000123'
        const {
            nonce,
            signature
        } = getPriceData(tokenAddress, tradePrice) 
        expect(await SatoshiOpstion_Charm.callStatic.checkIdentity([
            tokenAddress,
            tradePrice,
            nonce,
            signature
        ])).to.equal(true);
    })

    it("owner open", async function () {
        let [owner] = await ethers.getSigners()

        console.log(
            charm_token.address,
            owner.address,
            'owner balance:',
            getNumForBig(await charm_token.balanceOf(owner.address))
        )

        let tx;

        tx = await charm_token.approve(SatoshiOpstion_Charm.address, MAX_UINT256)
        await tx.wait()

        const tokenAddress = charm_token.address
        const tradePrice = '1'
        const {
            nonce,
            signature
        } = getPriceData(tokenAddress, tradePrice) 

        tx = await SatoshiOpstion_Charm.open(
            true,
            getInt128(ltable[0].delta),
            getInt128(2),
            getInt128(1e18),
            [
                tokenAddress,
                tradePrice,
                nonce,
                signature
            ]
        )
        await tx.wait()

        let balanceNFT = await SatoshiOpstion_Charm.balanceOf(owner.address, 0)
        console.log(
            "nft balance: ",
            getNumForBig(balanceNFT)
        )
        
    });

    it("close", async () => {
        let [owner] = await ethers.getSigners()
        const tokenAddress = charm_token.address
        const tradePrice = '2'
        const {
            nonce,
            signature
        } = getPriceData(tokenAddress, tradePrice)
        let balanceNFT = await SatoshiOpstion_Charm.balanceOf(owner.address, 0)
        console.log(
            "nft balance: ",
            getNumForBig(balanceNFT)
        )
        tx = await SatoshiOpstion_Charm.close(
            0,
            balanceNFT,
            [
                tokenAddress,
                tradePrice,
                nonce,
                signature
            ]
        )
        await tx.wait()
        balanceNFT = await SatoshiOpstion_Charm.balanceOf(owner.address, 0)
        console.log(
            "closed nft balance: ",
            getNumForBig(balanceNFT)
        )

        let balance = await charm_token.balanceOf(owner.address)
        console.log(
            "closed charm balance: ",
            getNumForBig(balance)
        )
    })


});
