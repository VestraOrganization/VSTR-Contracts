require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/ethereumjs-vm");
require('@openzeppelin/hardhat-upgrades');
require('dotenv').config();
require('hardhat-deploy');


module.exports = {
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: {
      default: 0, // default hardhat deployer account zero
    },
  },
  networks: {
    localhost: {
      chainId: 31337,
      url: "http://127.0.0.1:8545",
      gas: 30000000
    },
    sepolia: {
      url: process.env.ALCHEMY_SEPOLIA_URL, 
      accounts: [`0x${process.env.ACCOUNT_2_PRIVATEKEY}`], 

    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      debug: {
        revertStrings: "debug",
      },
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 100000
  },
  sourcify: {
    enabled: true
  }  
};
