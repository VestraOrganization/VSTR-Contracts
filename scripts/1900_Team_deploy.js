const { ethers, network } = require("hardhat");
const saveContractAddress = require("../utils/saveContractAddress");
const path = require('path');
const saveTransactionGasUsed = require("../utils/saveTransactionGasUsed");
const adresses = require("./0000_addresses.json")
const { DATA } = require("../utils/opt")

const opt = {
  owner: DATA.deploy.ownerAddress,
  contractName: DATA.team.contractName,
  launchTime: DATA.dao.launchTime,
  tokenAddress: DATA.deploy.tokenAddress,
  nftAddress: DATA.deploy.nftAddress,
  waitingTime: DATA.team.waitingTime,
  unlockPeriods: DATA.team.unlockPeriods,
}

async function main() {

  const CONTRACT = await ethers.getContractFactory(opt.contractName);
  const contract = await CONTRACT.deploy(opt.tokenAddress, opt.nftAddress, opt.waitingTime, opt.unlockPeriods);

  
  console.log("Deploy Verify Options: ### ", contract.target,
  opt.tokenAddress, opt.nftAddress, opt.waitingTime, opt.unlockPeriods, " ###"
  );


  const deploymentTransaction = await contract.deploymentTransaction();
  const receipt = await deploymentTransaction.wait();

  await contract.waitForDeployment();

  await saveContractAddress(opt.contractName, contract.target);
  await saveTransactionGasUsed(path.basename(__filename), receipt.gasUsed.toString())
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
