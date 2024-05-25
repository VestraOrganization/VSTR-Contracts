const { ethers, network} = require("hardhat");
const path = require('path');
const saveTransactionGasUsed = require("../utils/saveTransactionGasUsed");
const adresses = require("./0000_addresses.json")
const { DATA } = require("../utils/opt")


const opt = {
  owner: DATA.deploy.ownerAddress,
  tokenAddress: DATA.deploy.tokenAddress,

  contractName:     DATA.stakingLock.contractName,
  maturity:         DATA.stakingLock.periods.twelve.maturity,
  name:             DATA.stakingLock.periods.twelve.name,
  apr:              DATA.stakingLock.periods.twelve.apr,
  unlockTime:       DATA.stakingLock.periods.twelve.unlockTime,
  poolReward:       DATA.stakingLock.periods.twelve.poolReward,
  maxAccountStake:  DATA.stakingLock.periods.twelve.maxAccountStake,
  totalCap:         DATA.stakingLock.periods.twelve.totalCap,
  lateUnStakeFee:   DATA.stakingLock.periods.twelve.lateUnStakeFee,
}

async function main() {

  const contractABI = require('../artifacts/contracts/' + opt.contractName + ".sol/" + opt.contractName + ".json");

  const Contract = await ethers.getContractAt(contractABI.abi, adresses[network.name][opt.contractName]);

  try {
    const tx = await Contract.createMaturityStake(
      opt.maturity,
      opt.name,
      opt.apr,
      opt.unlockTime,
      opt.poolReward,
      opt.maxAccountStake,
      opt.totalCap,
      opt.lateUnStakeFee
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
