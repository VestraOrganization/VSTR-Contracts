const { ethers, run } = require("hardhat");
const adresses = require("./0000_addresses.json")
const { DATA } = require("../utils/opt")

const opt = {
  contractName: DATA.stakingLock.contractName,
  ownerAddress: DATA.deploy.ownerAddress,
  tokenAddress: DATA.deploy.tokenAddress,
  launchTime: DATA.stakingLock.launchTime,
  rewardPeriod: DATA.stakingLock.rewardPeriod,
  penaltySecond: DATA.stakingLock.penaltySecond,
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
        opt.ownerAddress, opt.tokenAddress, opt.launchTime, opt.penaltySecond
      ],
    });
    console.log("Contract is verified.");
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
