const { ethers, network } = require("hardhat");
const saveContractAddress = require("../utils/saveContractAddress");
const path = require('path');
const saveTransactionGasUsed = require("../utils/saveTransactionGasUsed");
const { DATA } = require("../utils/opt")

const opt = {
  owner: DATA.deploy.ownerAddress,
  contractName: DATA.NFT.contractName,
  name: DATA.NFT.name,
  symbol: DATA.NFT.symbol,
  baseURI: DATA.NFT.baseURI,
}

async function main() {

  const CONTRACT = await ethers.getContractFactory(opt.contractName);
  const contract = await CONTRACT.deploy(opt.owner, opt.name, opt.symbol, opt.baseURI);
  console.log("Deploy Verify Options: ### ", contract.target,
    opt.owner, opt.name, opt.symbol, opt.baseURI, " ###"
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
