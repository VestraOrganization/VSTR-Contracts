const { ethers, network } = require("hardhat");
const path = require('path');
const saveTransactionGasUsed = require("../utils/saveTransactionGasUsed");
const adresses = require("./0000_addresses.json")
const { DATA } = require("../utils/opt")


const opt = {
  owner: DATA.deploy.ownerAddress,
  contractName: DATA.dao.contractName,
  name: DATA.daoCategories.Development.name,
  amount: DATA.daoCategories.Development.amount,
  tge: DATA.daoCategories.Development.tge,
  cliffTime: DATA.daoCategories.Development.cliffTime,
  afterCliffUnlockPerThousand: DATA.daoCategories.Development.afterCliffUnlockPerThousand,
  unlockPeriods: DATA.daoCategories.Development.unlockPeriods,
  unlockPerThousand: DATA.daoCategories.Development.unlockPerThousand,
}

async function main() {

  const contractABI = require('../artifacts/contracts/' + opt.contractName + ".sol/" + opt.contractName + ".json");

  const Contract = await ethers.getContractAt(contractABI.abi, adresses[network.name][opt.contractName]);


  try {
    const tx = await Contract.createCategory(
      opt.name,
      opt.amount,
      opt.tge,
      opt.cliffTime,
      opt.afterCliffUnlockPerThousand,
      opt.unlockPeriods,
      opt.unlockPerThousand
    );
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
