// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

// xps deployed to: 0x0165878A594ca255338adfa4d48449f69242Eb8F
// relation deployed to: 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853
// lockControl deployed to: 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6

const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
    const Cppc = await hre.ethers.getContractFactory("contracts/Cppc.sol:Cppc");
    const cppc = await Cppc.deploy();
    console.log(`export const cppc = '${cppc.address}'`);

    const SatoshiOpstion = await hre.ethers.getContractFactory("contracts/SatoshiOpstion.sol:SatoshiOpstion");

    const satoshiOpstion = await SatoshiOpstion.deploy(cppc.address, 'btc-opstion', 'BTC_OP');
    console.log(`export const SatoshiOpstion = '${satoshiOpstion.address}'`);

    let tx = await cppc.setupMinterRole(satoshiOpstion.address)
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
