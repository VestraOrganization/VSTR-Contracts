const holders = require("./holders")
const { ethers, network } = require("hardhat");
const BigNumber = require('bignumber.js');


function _log(param, str = false) {
    if (str) {
        return console.log(str, param);
    } else {
        return console.log(param);
    }
}

function formatNumber(number, decimals = 6) {
    number = Number(number);
    return number.toLocaleString('en-EN', { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
}

/**
 * @param {*} val 
 * @param {*} decimal 
 * @returns 
 */
function numToParse(val, decimal = 18) {
    return ethers.parseUnits(val, decimal).toString();
}
/**
 * @param {*} val 
 * @param {*} decimal 
 * @returns 
 */
function numToFormat(val, decimal = 18) {
    return ethers.formatUnits(val, decimal).toString();
}

function parseUnits(val, formatDecimal = 18, unitDecimal = 2){
    return formatNumber(numToFormat(val, formatDecimal), unitDecimal);
}

/**
 * @param {*} year 
 * @param {*} month 
 * @param {*} day 
 * @param {*} hour 
 * @param {*} minute 
 * @param {*} second 
 * @returns Local timestamp
 */
function timestampLocal(year, month, day, hour = 0, minute = 0, second = 0) {
    const date = new Date(year, month - 1, day, hour, minute, second);
    return Math.floor(date.getTime() / 1000);
}

/**
 * @param {*} year 
 * @param {*} month 
 * @param {*} day 
 * @param {*} hour 
 * @param {*} minute 
 * @param {*} second 
 * @returns Unix GMT timestamp
 */
function timestampGMT(year, month, day, hour = 0, minute = 0, second = 0) {
    const timestamp = Date.UTC(year, month - 1, day, hour, minute, second);
    return Math.floor(timestamp / 1000);
}
/**
 * @returns Hardhat EVM timestamp
 */
async function timestampEVM() {
    const block = await network.provider.send("eth_getBlockByNumber", ["latest", false]);
    return parseInt(block.timestamp, 16);
}

/**
 * 
 * @param {*} seconds 
 * @returns remaining time
 */
function timestampSecond(seconds) {
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    const months = Math.floor(days / 30);
    const years = Math.floor(days / 360);

    const remainingSeconds = seconds % 60;
    const remainingMinutes = minutes % 60;
    const remainingHours = hours % 24;
    const remainingDays = days % 30;
    const remainingMonths = months % 12;

    let res = "";
    if (years !== 0) {
        res += years + " yıl ";
    }
    if (remainingMonths !== 0) {
        res += remainingMonths + " ay ";
    }
    if (remainingDays !== 0) {
        res += remainingDays + " gün ";
    }
    if (remainingHours !== 0) {
        res += remainingHours + " saat ";
    }
    if (remainingMinutes !== 0) {
        res += remainingMinutes + " dakika ";
    }
    if (remainingSeconds !== 0 || res === "") {
        res += remainingSeconds + " saniye";
    }

    return res.trim();
}

/**
 * @param {*} timestamp 
 * @returns DD.MM.YYYY HH:II:SS
 */
function timestampFormat(timestamp) {
    const date = new Date(Number(timestamp) * 1000);
    const day = date.getDate();
    const month = date.getMonth() + 1;
    const year = date.getFullYear();
    const hours = date.getHours();
    const minutes = date.getMinutes();
    const seconds = date.getSeconds();

    return `${day}.${month}.${year} ${hours}:${minutes}:${seconds}`;
}



async function gasUsed(tx, str = "gasUsed", res = false) {
    let wait = await tx.wait();
    let gas = wait.gasUsed.toString();
    if (res) {
        return gas;
    } else {
        console.log(`${str} ${gas}`);
    }

}

async function goToTime(year, month, day, hour = 0, minute = 0, second = 0) {
    await network.provider.send("evm_setNextBlockTimestamp", [timestampLocal(year, month, day, hour, minute, second)]);
    await network.provider.send("evm_mine");
    console.log("Current Time", await currentTime());
}

async function goToAddTime(time) {
    await network.provider.send("evm_increaseTime", [time]);
    await network.provider.send("evm_mine");
    console.log("Current Time", await currentTime());
}

async function goToTimeStamp(timestamp) {
    await network.provider.send("evm_setNextBlockTimestamp", [timestamp]);
    await network.provider.send("evm_mine");
    console.log("Current Time", await currentTime());
}

async function currentTime(params = "") {
    return params +  timestampFormat(await timestampEVM())
}

function randomInteger(min = 1, max = 100) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}


async function saveDataFile(data, filePath) {
    const fs = require('fs');
    const path = require('path');
    const savePath = path.join(path.resolve(__dirname, '..'), filePath);
    try {
        // Belirtilen dosya yolunu kullanarak dizinleri oluştur (eğer yoksa)
        const dir = path.dirname(savePath);
        fs.mkdirSync(dir, { recursive: true });

        // Veriyi string türüne dönüştürün
        const dataToWrite = typeof data === 'string' ? data : JSON.stringify(data);

        // Veriyi belirtilen dosyaya yaz
        fs.writeFileSync(savePath, dataToWrite, 'utf8');
        console.log(filePath + ' kaydedildi:');
    } catch (err) {
        console.error(filePath + ' yazılırken hata oluştu:', err);
    }
}


module.exports = {
    _log,
    formatNumber,
    numToParse,
    numToFormat,
    parseUnits,
    timestampLocal,
    timestampGMT,
    timestampEVM,
    timestampFormat,
    timestampSecond,
    gasUsed,
    goToTime,
    goToAddTime,
    goToTimeStamp,
    currentTime,
    randomInteger,
    saveDataFile
};