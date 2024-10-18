const { ethers, network } = require("hardhat");
const saveContractAddress = require("../utils/saveContractAddress");
const path = require('path');
const saveTransactionGasUsed = require("../utils/saveTransactionGasUsed");
const { DATA } = require("../utils/opt")


const opt = {
  owner: DATA.deploy.ownerAddress,
  usdtAddress: DATA.deploy.usdtAddress,
  tokenAddress: DATA.deploy.tokenAddress,

  contractName: DATA.publicSale.contractName,
  pool: DATA.publicSale.pool,
  startTime: DATA.publicSale.startTime,
  endTime: DATA.publicSale.endTime,
  startVestingTime: DATA.publicSale.startVestingTime,
  cliffTime: DATA.publicSale.cliffTime,
  unlockPeriods: DATA.publicSale.unlockPeriods,
}

async function main() {
  
  const CONTRACT = await ethers.getContractFactory(opt.contractName);

  const contract = await CONTRACT.deploy(
    opt.owner, opt.usdtAddress, opt.tokenAddress, opt.pool, opt.startTime, opt.endTime, opt.startVestingTime, opt.cliffTime, opt.unlockPeriods
  );

  console.log("Deploy Verify Options: ### ", contract.target,
    opt.owner, opt.usdtAddress, opt.tokenAddress, opt.pool, opt.startTime, opt.endTime, opt.startVestingTime, opt.cliffTime, opt.unlockPeriods, " ###"
  );


  const deploymentTransaction = await contract.deploymentTransaction();
  const receipt = await deploymentTransaction.wait();

  await contract.waitForDeployment()

  await saveContractAddress(opt.contractName, contract.target);
  await saveTransactionGasUsed(path.basename(__filename), receipt.gasUsed.toString())
}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
