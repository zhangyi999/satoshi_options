
const hre = require("hardhat");
const {ethers, upgrades} = hre

const TOKEN_ADDRESS = ""
const SIGNER_ADDRESS = ""

async function main() {
  //////// config ////////
  let config = await ethers.getContractFactory("contracts/Config.sol:Config");

  config = await config.deployed();

  console.log("config address: ", config.address)

  let tx = await config.setConfig([

  ])
  console.log("set config hash: ",tx.hash)
  await tx.wait()

  tx = await config.setLTable([
    []
  ])
  console.log("set LTable hash: ",tx.hash)
  await tx.wait()

  //////// 线性期权 ////////
  let SatoshiOpstion_Charm = await ethers.getContractFactory("SatoshiOpstion_Charm");
  SatoshiOpstion_Charm = await upgrades.deployProxy(SatoshiOpstion_Charm,[
    'SatoshiOpstion_Charm',
    'SatoshiOpstion_Charm NFT',
    TOKEN_ADDRESS,
    config.address
  ]);
  console.log("SatoshiOpstion_Charm to: ", SatoshiOpstion_Charm.address)

  tx = await SatoshiOpstion_Charm.setDataProvider(
    SIGNER_ADDRESS
  )
  console.log("set siger hash: ",tx.hash)
  await tx.wait()

  //////// 二元期权 ////////
  let SatoshiOpstion_Charm_2 = await ethers.getContractFactory("SatoshiOpstion_Charm_Two");
  SatoshiOpstion_Charm_2 = await upgrades.deployProxy(SatoshiOpstion_Charm_2,[
    'SatoshiOpstion_Charm_2',
    'SatoshiOpstion_Charm_2 NFT',
    TOKEN_ADDRESS,
    config.address
  ]);
  console.log("SatoshiOpstion_Charm to: ", SatoshiOpstion_Charm_2.address)

  tx = await SatoshiOpstion_Charm_2.setDataProvider(
    SIGNER_ADDRESS
  )
  console.log("set siger hash: ",tx.hash)
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
