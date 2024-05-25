const { ethers, network } = require("hardhat");
const func = require("./funcs")
const addresses = require("../scripts/0000_addresses.json");
const holders = require("./holders");


const PRIVATESALE_START_TIME = func.timestampLocal(2024, 12, 1, 0, 0, 0);
const LAUNCH_TIME = func.timestampLocal(2025, 1, 1, 0, 0, 0);

const DAY_TIME = (60 * 60 * 24); 
const MONTH_TIME = (DAY_TIME * 30); 

const DATA = {
    deploy: {
        ownerAddress: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        usdtAddress:  addresses.localhost.USDV,
        tokenAddress: addresses.localhost.VDAOToken,
        nftAddress:   addresses.localhost.CMLENFT,
        daoAddress:   addresses.localhost.VDAO,

    }, delegate: [
        "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // Delegate 1
        "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", // Delegate 2
        "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", // Delegate 3
        "0x90F79bf6EB2c4f870365E785982E1f101E93b906", // Delegate 4
        "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65", // Delegate 5
        "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc", // Delegate 6
        "0x976EA74026E726554dB657fA54763abd0C3a0aa9", // Delegate 7

    ],
    dao: {
        contractName: "VDAO",
        launchTime: LAUNCH_TIME,
        electionPeriod: (60 * 60 * 24 * 365 * 3),
        candTime: (60 * 60 * 24 * 10),
        votingTime: (60 * 60 * 24 * 10),
        proposalVotingTime: (60 * 60 * 24 * 3),
        pool: func.numToParse("35750000000", 18),
    },
    USDV: {
        contractName: "USDV",
        name: "USDV Stable Token",
        symbol: "USDV",
        decimals: "6"
    },
    token: {
        contractName: "VDAOToken",
        name: "Vestra DAO",
        symbol: "VDAO",
        decimals: "18",
        totalSupply: "50000000000"
    },
    NFT: {
        contractName: "CMLENFT",
        name: "Crypto Monster Limited Edition",
        symbol: "CMLE",
        totalSupply: "502",
        baseURI: "https://cmlenft.fun/nft/"
    },
    airdrop: {
        contractName: "VDAOAirdrop",
        // TGE 20%, 3 Ay Kilit Açılımı Yok, Daha sonra Aylık 4% açılacak.
        // YYYY:MM:DD HH:MM:SS (Yıl:Ay:Gün-Saat:Dakika:Saniye)
        launchTime: LAUNCH_TIME,     // vesting başlangıcı (ilk claim edeceği zaman) x gün
        waitingTime: MONTH_TIME * 3,             // ilk açılıştan sonraki bekleme süresi x gün
        unlockPeriods: MONTH_TIME,             // ne kadarlık zaman diliminde açılacağı x gün
        pool: func.numToParse("1000000000", 18) // Havuz Büyüklüğü:
    },
    privateSale: {
        // TGE 10%, 3 Ay Kilit Açılımı Yok, Daha sonra Aylık 5% açılacak.
        contractName: "PrivateSale",
        // Private Sale başlangıç zamanı
        startTime: PRIVATESALE_START_TIME,                           
        // Private Sale bitiş zamanı
        endTime: PRIVATESALE_START_TIME + (60 * 60 * 24 * 14) ,
        // vesting başlangıcı (ilk claim edeceği zaman) x gün
        startVestingTime: LAUNCH_TIME ,
        // ilk açılıştan sonraki bekleme süresi x gün (60 * 60 * 24 * 90) = 3 ay 
        waitingTime: MONTH_TIME * 3,            
        // ne kadarlık zaman diliminde açılacağı x gün (60 * 60 * 24 * 30) = 1 ay
        unlockPeriods: MONTH_TIME,
        pool: func.numToParse("2000000000", 18) // Havuz Büyüklüğü:
    },
    stakingDao: {
        /*
        ❗ Pro Wallet Staking

        Toplam Havuz Büyüklüğü: 1.000.000.000 
        Zorunlu Stake Miktarı: 2.000.000 
        Stake Oluşturma Üst Limiti: 1 
        Günlük Ödül Dağılımı: 500.000 
        */
        contractName: "StakingDAO",
        launchTime: LAUNCH_TIME, // stake başlama tarihi
        lockPeriod: MONTH_TIME * 24, // Kilit süresi 2 yıl
        rewardPeriod: DAY_TIME, // ödül toplama zamanları 1 gün
        pool: func.numToParse("1000000000", 18),
    },
    stakingFlexible: {
        contractName: "StakingFlexible",
        launchTime: LAUNCH_TIME, // stake başlama tarihi
        rewardPeriod: DAY_TIME, // ödül toplama zamanları 1 gün
        pool: func.numToParse("750000000", 18),
    },
    stakingLock: {
        contractName: "StakingLock",
        launchTime: LAUNCH_TIME, // stake başlama tarihi
        pool: func.numToParse("750000000", 18),
        penaltySecond: (60 * 60 * 24), // 1 gün kesinti hesaplama süresi
        periods: {
            one: {
                maturity: 1,
                name: "1 Month",
                apr: 4,
                unlockTime: MONTH_TIME, // 1 ay
                poolReward: func.numToParse("1875000", 18),
                maxAccountStake: func.numToParse("500000", 18),
                totalCap: func.numToParse("46875000", 18),
                lateUnStakeFee: (60 * 60 * 24 * 7), // 1 hafta
            },
            three: {
                maturity: 3,
                name: "3 Month",
                apr: 8,
                unlockTime: MONTH_TIME * 3, // 3 ay
                poolReward: func.numToParse("5625000", 18),
                maxAccountStake: func.numToParse("750000", 18),
                totalCap: func.numToParse("70312000", 18),
                lateUnStakeFee: (60 * 60 * 24 * 7), // 1 hafta
            },
            six: {
                maturity: 6,
                name: "6 Month",
                apr: 12,
                unlockTime: MONTH_TIME * 6, // 6 ay
                poolReward: func.numToParse("11250000", 18),
                maxAccountStake: func.numToParse("1000000", 18),
                totalCap: func.numToParse("93750000", 18),
                lateUnStakeFee: (60 * 60 * 24 * 7 * 2), // 2 hafta
            },
            twelve: {
                maturity: 12,
                name: "12 Month",
                apr: 16,
                unlockTime: MONTH_TIME * 12, // 12 ay
                poolReward: func.numToParse("22500000", 18),
                maxAccountStake: func.numToParse("2000000", 18),
                totalCap: func.numToParse("140625000", 18),
                lateUnStakeFee: (60 * 60 * 24 * 7 * 2), // 2 hafta
            },
        }
    },
    daoCategories: {
        GameFi: {
            name: "GameFi", 
            amount: func.numToParse("4500000000", 18),   // amount
            tge: 50,                                // tge 1000/x
            cliffTime: MONTH_TIME * 12,    // cliffTime
            afterCliffUnlockPerThousand: 100,       // afterCliffUnlockPerThousand
            unlockPeriods: MONTH_TIME,     // unlockPeriods
            unlockPerThousand: 10                   // unlockPerThousand
        },
        Metaverse: {
            name: "Metaverse", 
            amount: func.numToParse("4000000000", 18),   // amount
            tge: 100,                               // tge 1000/x
            cliffTime: MONTH_TIME * 12,    // cliffTime
            afterCliffUnlockPerThousand: 300,       // afterCliffUnlockPerThousand
            unlockPeriods: MONTH_TIME * 3, // unlockPeriods
            unlockPerThousand: 30                   // unlockPerThousand
        },
        Collaborations: {
            name: "Collaborations", 
            amount: func.numToParse("2250000000", 18),   // amount
            tge: 200,                               // tge 1000/x
            cliffTime: MONTH_TIME * 9,    // cliffTime
            afterCliffUnlockPerThousand: 50,       // afterCliffUnlockPerThousand
            unlockPeriods: MONTH_TIME, // unlockPeriods
            unlockPerThousand: 50                   // unlockPerThousand
        },
        Investments: {
            name: "Investments",
            amount: func.numToParse("3750000000", 18),   // amount
            tge: 50,                               // tge 1000/x
            cliffTime: MONTH_TIME * 6,    // cliffTime
            afterCliffUnlockPerThousand: 10,       // afterCliffUnlockPerThousand
            unlockPeriods: MONTH_TIME, // unlockPeriods
            unlockPerThousand: 10                   // unlockPerThousand
        },
        Marketing: {
            name: "Marketing", 
            amount: func.numToParse("1750000000", 18),   // amount
            tge: 100,                               // tge 1000/x
            cliffTime: MONTH_TIME * 12,    // cliffTime
            afterCliffUnlockPerThousand: 10,       // afterCliffUnlockPerThousand
            unlockPeriods: MONTH_TIME, // unlockPeriods
            unlockPerThousand: 10                   // unlockPerThousand
        },
        Development: {
            name: "Development", 
            amount: func.numToParse("1650000000", 18),   // amount
            tge: 150,                               // tge 1000/x
            cliffTime: MONTH_TIME * 3,    // cliffTime
            afterCliffUnlockPerThousand: 25,       // afterCliffUnlockPerThousand
            unlockPeriods: MONTH_TIME, // unlockPeriods
            unlockPerThousand: 25                   // unlockPerThousand
        },
        Charities: {
            name: "Charities", 
            amount: func.numToParse("1250000000", 18),   // amount
            tge: 0,                               // tge 1000/x
            cliffTime: MONTH_TIME * 3,    // cliffTime
            afterCliffUnlockPerThousand: 10,       // afterCliffUnlockPerThousand
            unlockPeriods: MONTH_TIME, // unlockPeriods
            unlockPerThousand: 10                   // unlockPerThousand
        },
        Advisors: {
            name: "Advisors", 
            amount: func.numToParse("1350000000", 18),   // amount
            tge: 50,                               // tge 1000/x
            cliffTime: MONTH_TIME * 3,    // cliffTime
            afterCliffUnlockPerThousand: 15,       // afterCliffUnlockPerThousand
            unlockPeriods: MONTH_TIME, // unlockPeriods
            unlockPerThousand: 15                   // unlockPerThousand
        },
        Treasury: {
            name: "Treasury", 
            amount: func.numToParse("10000000000", 18),   // amount
            tge: 100,                               // tge 1000/x
            cliffTime: MONTH_TIME * 12,    // cliffTime
            afterCliffUnlockPerThousand: 50,       // afterCliffUnlockPerThousand
            unlockPeriods: MONTH_TIME * 3, // unlockPeriods
            unlockPerThousand: 50                   // unlockPerThousand
        },
        Bounties: {
            name: "Bounties", 
            amount: func.numToParse("1000000000", 18),   // amount
            tge: 1000,                               // tge 1000/x
            cliffTime: 0,    // cliffTime
            afterCliffUnlockPerThousand: 0,       // afterCliffUnlockPerThousand
            unlockPeriods: 1, // unlockPeriods
            unlockPerThousand: 0                   // unlockPerThousand
        },
        SocialFi: {
            name: "SocialFi", 
            amount: func.numToParse("4250000000", 18),   // amount
            tge: 1000,                               // tge 1000/x
            cliffTime: 0,    // cliffTime
            afterCliffUnlockPerThousand: 0,       // afterCliffUnlockPerThousand
            unlockPeriods: 1, // unlockPeriods
            unlockPerThousand: 0                   // unlockPerThousand
        },


    },
    team: {
        contractName: "Team",
        // TGE 10%, 12 Ay kilit açılımı yok, ardından aylık 1% açılacak.
        waitingTime: MONTH_TIME * 12,             // ilk açılıştan sonraki bekleme süresi x gün
        unlockPeriods: MONTH_TIME,             // ne kadarlık zaman diliminde açılacağı x gün
        pool: func.numToParse("7500000000", 18) // Havuz Büyüklüğü:
    },
    nftIds: holders.nftId,
    nftVote: holders.nftVote,
    nftName: holders.nftName,
    nftOwners: holders.nftOwners,
}
module.exports = {DATA};