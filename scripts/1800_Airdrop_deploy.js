const { ethers, network } = require("hardhat");
const saveContractAddress = require("../utils/saveContractAddress");
const path = require('path');
const saveTransactionGasUsed = require("../utils/saveTransactionGasUsed");
const { DATA } = require("../utils/opt")


const opt = {
  owner: DATA.deploy.ownerAddress,
  tokenAddress: DATA.deploy.tokenAddress,
  nftAddress: DATA.deploy.nftAddress,

  contractName: DATA.airdrop.contractName,
  waitingTime: DATA.airdrop.waitingTime,
  unlockPeriods: DATA.airdrop.unlockPeriods,
  launchTime: DATA.airdrop.launchTime,
}

async function main() {
  const CONTRACT = await ethers.getContractFactory(opt.contractName);

  const contract = await CONTRACT.deploy(
    opt.tokenAddress, opt.nftAddress,
    opt.launchTime,
    opt.waitingTime,
    opt.unlockPeriods
  );

  console.log("Deploy Verify Options: ### ", contract.target,
    opt.tokenAddress, opt.nftAddress,
    opt.launchTime,
    opt.waitingTime,
    opt.unlockPeriods, " ###"
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
