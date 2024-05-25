const { ethers, network } = require("hardhat");
const saveContractAddress = require("../utils/saveContractAddress");
const path = require('path');
const saveTransactionGasUsed = require("../utils/saveTransactionGasUsed");
const adresses = require("./0000_addresses.json")
const { DATA } = require("../utils/opt")

const opt = {
  owner: DATA.deploy.ownerAddress,
  contractName: DATA.dao.contractName,
  launchTime: DATA.dao.launchTime,
  electionPeriod: DATA.dao.electionPeriod,
  candTime: DATA.dao.candTime,
  votingTime: DATA.dao.votingTime,
  proposalVotingTime: DATA.dao.proposalVotingTime,
  owner: DATA.deploy.ownerAddress,
}

async function main() {
  const CONTRACT = await ethers.getContractFactory(opt.contractName);
  const contract = await CONTRACT.deploy(opt.owner, opt.launchTime, opt.electionPeriod, opt.candTime, opt.votingTime, opt.proposalVotingTime);

  console.log("Deploy Verify Options: ### ", contract.target,
  opt.owner, opt.launchTime, opt.electionPeriod, opt.candTime, opt.votingTime, opt.proposalVotingTime, " ###"
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
