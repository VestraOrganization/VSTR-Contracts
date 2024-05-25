const { ethers, run } = require("hardhat");
const adresses = require("./0000_addresses.json")
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
  if (network.name == "localhost") {
    console.log("You can't verify on Localhost. Network: " + network.name);
    return false;
  }
  // Sözleşmeyi Etherscan üzerinde doğrula
  console.log("Contract is verifying on Etherscan...");
  try {
    await run("verify:verify", {
      address: adresses[network.name][opt.contractName],
      constructorArguments: [
        opt.tokenAddress, opt.nftAddress,
        opt.launchTime,
        opt.waitingTime,
        opt.unlockPeriods
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
