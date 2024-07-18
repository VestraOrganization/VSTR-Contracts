const { network } = require("hardhat");
const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, './txGasUsed.json'); 

async function saveTransactionGasUsed(fileName, gasUsed) {
    let jsonData;
    try {
        jsonData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch (err) {
        console.error('Error occurred while reading the file:', err);
        jsonData = {};
    }

    if (!jsonData[network.name]) {
        jsonData[network.name] = {}; 
    }

    jsonData[network.name][fileName] = gasUsed;

    try {
        fs.writeFileSync(filePath, JSON.stringify(jsonData, null, 2), 'utf8');
        console.log(`${fileName} gasUsed: ${gasUsed}`);
    } catch (err) {
        console.error('Save gasUsed Error!:', err);
    }
}

module.exports = saveTransactionGasUsed;
