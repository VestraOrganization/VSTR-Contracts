const { network } = require("hardhat");
const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, '../scripts/0000_addresses.json'); // JSON dosyasının yolu

async function saveContractAddress(contractName, address) {
    let jsonData;
    try {
        jsonData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch (err) {
        console.error('Dosya okunurken hata oluştu:', err);
        jsonData = {};
    }

    // network.name özelliğinin olup olmadığını kontrol edin
    if (!jsonData[network.name]) {
        jsonData[network.name] = {}; // Eğer yoksa, oluşturun
    }

    jsonData[network.name][contractName] = address;

    try {
        fs.writeFileSync(filePath, JSON.stringify(jsonData, null, 2), 'utf8');
        console.log(`${contractName} save address: ${address} Network: ${network.name}`);
    } catch (err) {
        console.error('error save address:', err);
    }
}

module.exports = saveContractAddress;
