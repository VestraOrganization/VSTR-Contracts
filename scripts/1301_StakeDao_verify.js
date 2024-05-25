const { ethers, run } = require("hardhat");
const adresses = require("./0000_addresses.json")
const { DATA } = require("../utils/opt")

const opt = {
  contractName: DATA.stakingDao.contractName,
  ownerAddress: DATA.deploy.ownerAddress,
  tokenAddress: DATA.deploy.tokenAddress,
  launchTime: DATA.stakingDao.launchTime,
  rewardPeriod: DATA.stakingDao.rewardPeriod,
  lockPeriod: DATA.stakingDao.lockPeriod,
  pool: DATA.stakingDao.pool,
}

async function main() {
  if (network.name == "localhost") {
    console.log("You can't verify on Localhost. Network: " + network.name);
    return false;
  }
  console.log("Contract is verifying on Etherscan...");
  try {
    await run("verify:verify", {
      address: adresses[network.name][opt.contractName],
      constructorArguments: [
        opt.ownerAddress, opt.tokenAddress, opt.pool, opt.launchTime, opt.lockPeriod, opt.rewardPeriod
      ],
    });
    console.log("Sözleşme doğrulandı");
  } catch (error) {
    if (error.message.toLowerCase().includes("already verified")) {
      console.log("Contract has been verified already.");
    } else {
      throw error;
    }
  }

}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
