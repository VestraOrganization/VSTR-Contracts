const { ethers, network } = require("hardhat");
const path = require('path');
const saveTransactionGasUsed = require("../utils/saveTransactionGasUsed");
const adresses = require("./0000_addresses.json")
const { DATA } = require("../utils/opt")
const funcs = require("../utils/funcs")
const BigNumber = require('bignumber.js');

const opt = {
  tokenName: DATA.token.contractName
}
async function main() {


  const contractABI = require('../artifacts/contracts/' + opt.tokenName + ".sol/" + opt.tokenName + ".json");

  const Contract = await ethers.getContractAt(contractABI.abi, adresses[network.name][opt.tokenName]);
  adresses[network.name].owner = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

  let table = [];
  let totalBalance = BigNumber("0");

  for (const key in adresses[network.name]) {
    if(key =="USDT" || key =="VestraDAO" || key =="CMLENFT"){
      continue;
    }
    let balance = await Contract.balanceOf(adresses[network.name][key]);
    totalBalance = totalBalance.plus(balance);

    table.push({
      "ADDRESS": key,
      "BALANCE": funcs.parseUnits(balance, 18, 6)
    })
  }
  table.push({
    "ADDRESS": "<--TOTAL-->",
    "BALANCE": funcs.parseUnits(totalBalance.toFixed(), 18, 6)
  })
  console.table(table)



}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
