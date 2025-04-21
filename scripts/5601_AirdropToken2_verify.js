const { ethers, run } = require("hardhat");
const adresses = require("./0000_addresses.json")
const { DATA } = require("../utils/opt")


const opt = {
  owner: DATA.deploy.ownerAddress,
  tokenAddress: DATA.deploy.tokenAddress,
  contractName: "TokenAirdrop2"
}


async function main() {
  if (network.name == "localhost") {
    console.log("You can't verify on Localhost. Network: " + network.name);
    return false;
  }
  // manual verify: npx hardhat verify --network mainnet --contract contracts/TokenAirdrop2.sol:TokenAirdrop2 0xaF0c0886Dc15D2934661358B5672faFdc6C471e8 0x73395DD2954333Fe546414679B931fB08C84ae81 0x92D5942f468447f1F21c2092580F15544923b434
  console.log("Contract is verifying on Etherscan...");
  try {
    await run("verify:verify", {
      address: adresses[network.name][opt.contractName],
      constructorArguments: [
        opt.owner, opt.tokenAddress
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
