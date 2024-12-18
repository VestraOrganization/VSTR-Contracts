const { ethers, network } = require("hardhat");
const saveContractAddress = require("../utils/saveContractAddress");
const path = require('path');
const saveTransactionGasUsed = require("../utils/saveTransactionGasUsed");
const { DATA } = require("../utils/opt")
const func = require("../utils/funcs")


const opt = {
  owner: DATA.deploy.ownerAddress,
  tokenAddress: DATA.deploy.tokenAddress,
  contractName: "DonateCommunity"
}

async function main() {
  
  const CONTRACT = await ethers.getContractFactory(opt.contractName);

  const contract = await CONTRACT.deploy(
    opt.owner, opt.tokenAddress
  );

  console.log("Deploy Verify Options: ### ", contract.target,
    opt.owner, opt.tokenAddress, " ###"
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
