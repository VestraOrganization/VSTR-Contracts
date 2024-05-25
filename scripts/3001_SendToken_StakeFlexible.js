const { ethers, network } = require("hardhat");
const path = require('path');
const saveTransactionGasUsed = require("../utils/saveTransactionGasUsed");
const adresses = require("./0000_addresses.json")
const { DATA } = require("../utils/opt")
const funcs = require("../utils/funcs")

const opt = {
  tokenName: DATA.token.contractName,
  contractName: DATA.stakingFlexible.contractName,
  pool: DATA.stakingFlexible.pool,
}
async function main() {
  console.log(`
  ${opt.tokenName} address : ${adresses[network.name][opt.tokenName]}
  ${opt.contractName} address : ${adresses[network.name][opt.contractName]}
  `);

  const contractABI = require('../artifacts/contracts/' + opt.tokenName + ".sol/" + opt.tokenName + ".json");

  const Contract = await ethers.getContractAt(contractABI.abi, adresses[network.name][opt.tokenName]);

  try {
    const tx = await Contract.transfer(adresses[network.name][opt.contractName], opt.pool);
    
    const receipt = await tx.wait(); 
    console.log("Success tx:", receipt.hash);

    await saveTransactionGasUsed(path.basename(__filename), receipt.gasUsed.toString())
  } catch (error) {
    console.error("Error! Message:", error.message);
  }

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
