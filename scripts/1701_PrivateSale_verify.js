const { ethers, run } = require("hardhat");
const adresses = require("./0000_addresses.json")
const { DATA } = require("../utils/opt")

const opt = {
  owner: DATA.deploy.ownerAddress,
  usdtAddress: DATA.deploy.usdtAddress,
  tokenAddress: DATA.deploy.tokenAddress,
  nftAddress: DATA.deploy.nftAddress,

  contractName: DATA.privateSale.contractName,
  startTime: DATA.privateSale.startTime,                           // Private Sale başlangıç zamanı
  endTime: DATA.privateSale.endTime,                               // Private Sale bitiş zamanı
  startVestingTime: DATA.privateSale.startVestingTime, // vesting başlangıcı (ilk claim edeceği zaman) x gün
  waitingTime: DATA.privateSale.waitingTime,             // ilk açılıştan sonraki bekleme süresi x gün (60 * 60 * 24 * 90) = 3 ay
  unlockPeriods: DATA.privateSale.unlockPeriods,             // ne kadarlık zaman diliminde açılacağı x gün (60 * 60 * 24 * 30) = 1 ay

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
        opt.owner, opt.usdtAddress, opt.tokenAddress, opt.nftAddress,
    opt.startTime, opt.endTime,
    opt.startVestingTime, opt.waitingTime, opt.unlockPeriods
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
