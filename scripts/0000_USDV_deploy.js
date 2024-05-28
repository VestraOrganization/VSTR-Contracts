const { ethers, network } = require("hardhat");
const saveContractAddress = require("../utils/saveContractAddress");
const { DATA } = require("../utils/opt")

async function main() {

  const CONTRACT = await ethers.getContractFactory(DATA.USDV.contractName);

  const contract = await CONTRACT.deploy();

  await contract.waitForDeployment()
  await saveContractAddress(DATA.USDV.contractName, contract.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
