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
 * Gelen değere desimal ekler
 * @param {*} val 
 * @param {*} decimal 
 * @returns 
 */
function numToParse(val, decimal = 18) {
    return ethers.parseUnits(val, decimal).toString();
}
/**
 * Gelen değerden desimali kaldırır
 * @param {*} val 
 * @param {*} decimal 
 * @returns 
 */
function numToFormat(val, decimal = 18) {
    return ethers.formatUnits(val, decimal).toString();
}

function parseUnits(val, formatDecimal = 18, unitDecimal = 2) {
    return formatNumber(numToFormat(val, formatDecimal), unitDecimal);
}

/**
 * Gelen Yıl, Ay, Gün, Saat, Dakika, Saniye'yi local zaman damgasına çevirir 
 * @param {*} year 
 * @param {*} month 
 * @param {*} day 
 * @param {*} hour 
 * @param {*} minute 
 * @param {*} second 
 * @returns 
 */
function timestampLocal(year, month, day, hour = 0, minute = 0, second = 0) {
    const date = new Date(year, month - 1, day, hour, minute, second);
    return Math.floor(date.getTime() / 1000); // Unix timestamp saniye cinsinden döndürülür
}

/**
 * Gelen Yıl, Ay, Gün, Saat, Dakika, Saniye'yi GMT zaman damgasına çevirir 
 * @param {*} year 
 * @param {*} month 
 * @param {*} day 
 * @param {*} hour 
 * @param {*} minute 
 * @param {*} second 
 * @returns 
 */
function timestampGMT(year, month, day, hour = 0, minute = 0, second = 0) {
    const timestamp = Date.UTC(year, month - 1, day, hour, minute, second);
    return Math.floor(timestamp / 1000); // Unix timestamp saniye cinsinden döndürülür
}
/**
 * Hardhat EVM timestampını verir
 * @returns 
 */
async function timestampEVM() {
    const block = await network.provider.send("eth_getBlockByNumber", ["latest", false]);
    return parseInt(block.timestamp, 16);
}



/**
 * gelen değere ne kadar süre kaldığını gösterir
 * @param {*} seconds 
 * @returns 
 */
function timestampSecond(seconds) {
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    const months = Math.floor(days / 30);
    const years = Math.floor(days / 360);

    const remainingSeconds = seconds % 60; // Saniye hesaplaması eklendi
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
    if (remainingSeconds !== 0 || res === "") { // Eğer diğer tüm değerler 0 ise ya da res henüz boş ise saniyeyi ekle
        res += remainingSeconds + " saniye";
    }

    return res.trim();
}

/**
 * gelen timestampı tarih ve saate formatlar DD:MM:YYYY HH:II:SS
 * @param {*} timestamp 
 * @returns 
 */
function timestampFormat(timestamp) {
    const date = new Date(Number(timestamp) * 1000); // Timestamp'ı milisaniyeye çeviriyoruz.

    const day = date.getDate();
    const month = date.getMonth() + 1; // JavaScript'te aylar 0'dan başlar (0=Ocak, 1=Şubat, ...)
    const year = date.getFullYear();
    const hours = date.getHours();
    const minutes = date.getMinutes();
    const seconds = date.getSeconds();

    return `${day}.${month}.${year} ${hours}:${minutes}:${seconds}`;
}

/**
 * tokenin fiyatını hesaplar
 * @param {*} tokenAmount 
 * @param {*} decimals 
 * @returns 
 */
function tokenToPrice(tokenAmount, decimals = 18) {
    let amount = new BigNumber(numToFormat(tokenAmount, decimals));
    return amount.multipliedBy(0.0007).toFixed();
}
/**
 * gelen değerin yüzdeliğini hesaplar
 * @param {*} tokenAmount 
 * @param {*} percent 
 * @returns 
 */
function percentAmount(amount, percent) {
    let num = new BigNumber(amount.toString());
    return num.div(100).multipliedBy(percent).toFixed()
}

function percentPlus(amount, percent) {
    let num = new BigNumber(amount.toString());
    return num.div(100).multipliedBy(percent).plus(amount).toFixed()
}


/**
 * Transactionun harcadığı gas miktarını yazdırır
 * @param {*} tx 
 * @param {*} str 
 */
async function gasUsed(tx, str = "gasUsed", res = false) {
    let wait = await tx.wait();
    let gas = wait.gasUsed.toString();
    if (res) {
        return gas;
    } else {
        console.log(`${str} ${gas}`);
    }

}
/**
 * ilgili zamana gider
 * @param {*} year 
 * @param {*} month 
 * @param {*} day 
 * @param {*} hour 
 * @param {*} minute 
 * @param {*} second 
 */
async function goToTime(year, month, day, hour = 0, minute = 0, second = 0) {
    await network.provider.send("evm_setNextBlockTimestamp", [timestampLocal(year, month, day, hour, minute, second)]);
    await network.provider.send("evm_mine");
    //console.log("Current Time", await currentTime());
}

/**
 * gelen süreyi mevcut zamanın üzerine ekle
 * @param {*} time 
 */
async function goToAddTime(time, log = true) {
    await network.provider.send("evm_increaseTime", [time]);
    await network.provider.send("evm_mine");
    if (!log) {
        console.log("\t\tCurrent Time: ", await currentTime());
    }
}

async function currentTime(params = " ") {
    return params + " " + timestampFormat(await timestampEVM())
}

function randomInteger(min = 500, max = 100000) {
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

// await network.provider.send("evm_increaseTime", [(60*60*24)]); // mevcut timestampa ekleme yapar
// await network.provider.send("evm_setNextBlockTimestamp", [launchpad.startSaleTime]) // belirtilen zaman damgasına gider
// await network.provider.send("evm_mine");
// await network.provider.send("eth_getBlockByNumber", ["latest", false]) // hardhat timestamp 

function getContractAbi(contractName){
    const contract = require('../artifacts/contracts/'+contractName+'.sol/'+contractName+'.json');
    return contract.abi;
}

function inputDataDecode(contractName, inputData){
    const iface = new ethers.Interface(getContractAbi(contractName))
    return iface.parseTransaction({ data: inputData });
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
    tokenToPrice,
    percentAmount,
    percentPlus,
    gasUsed,
    goToTime,
    goToAddTime,
    currentTime,
    randomInteger,
    saveDataFile,
    inputDataDecode
};