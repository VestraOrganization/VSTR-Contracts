const { ethers, network } = require("hardhat");
const saveContractAddress = require("../utils/saveContractAddress");
const path = require('path');
const saveTransactionGasUsed = require("../utils/saveTransactionGasUsed");
const { DATA } = require("../utils/opt")

const opt = {
  owner: DATA.deploy.ownerAddress,
  contractName: DATA.token.contractName,
  tokenName: DATA.token.name,
  tokenSymbol: DATA.token.symbol,
  tokenTotalSupply: DATA.token.totalSupply
}



async function main() {

  const CONTRACT = await ethers.getContractFactory(opt.contractName);

  const contract = await CONTRACT.deploy(opt.owner, opt.tokenName, opt.tokenSymbol);


  const deploymentTransaction = await contract.deploymentTransaction();
  const receipt = await deploymentTransaction.wait();

  await contract.waitForDeployment()

  await saveContractAddress(DATA.token.contractName, contract.target);
  await saveTransactionGasUsed(path.basename(__filename), receipt.gasUsed.toString())
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
