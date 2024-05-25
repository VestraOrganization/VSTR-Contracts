const { ethers, network } = require("hardhat");
const saveContractAddress = require("../utils/saveContractAddress");
const path = require('path');
const saveTransactionGasUsed = require("../utils/saveTransactionGasUsed");
const { DATA } = require("../utils/opt")


const opt = {
  owner: DATA.deploy.ownerAddress,
  usdtAddress: DATA.deploy.usdtAddress,
  tokenAddress: DATA.deploy.tokenAddress,
  nftAddress: DATA.deploy.nftAddress,

  contractName: DATA.privateSale.contractName,
  startTime: DATA.privateSale.startTime, 
  endTime: DATA.privateSale.endTime,
  startVestingTime: DATA.privateSale.startVestingTime,
  waitingTime: DATA.privateSale.waitingTime,
  unlockPeriods: DATA.privateSale.unlockPeriods,

}


async function main() {
  const CONTRACT = await ethers.getContractFactory(opt.contractName);
  const contract = await CONTRACT.deploy(
    opt.owner, opt.usdtAddress, opt.tokenAddress, opt.nftAddress,
    opt.startTime, opt.endTime,
    opt.startVestingTime, opt.waitingTime, opt.unlockPeriods);

  console.log("Deploy Verify Options: ### ", contract.target,
    opt.owner, opt.usdtAddress, opt.tokenAddress, opt.nftAddress,
    opt.startTime, opt.endTime,
    opt.startVestingTime, opt.waitingTime, opt.unlockPeriods, " ###"
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
