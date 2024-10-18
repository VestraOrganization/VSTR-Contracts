const { ethers, run } = require("hardhat");
const adresses = require("./0000_addresses.json")
const { DATA } = require("../utils/opt")


const opt = {
  owner: DATA.deploy.ownerAddress,
  usdtAddress: DATA.deploy.usdtAddress,
  tokenAddress: DATA.deploy.tokenAddress,

  contractName: DATA.publicSale.contractName,
  pool: DATA.publicSale.pool,
  startTime: DATA.publicSale.startTime,
  endTime: DATA.publicSale.endTime,
  startVestingTime: DATA.publicSale.startVestingTime,
  cliffTime: DATA.publicSale.cliffTime,
  unlockPeriods: DATA.publicSale.unlockPeriods,
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
        opt.owner, opt.usdtAddress, opt.tokenAddress, opt.pool, opt.startTime, opt.endTime, opt.startVestingTime, opt.cliffTime, opt.unlockPeriods
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
