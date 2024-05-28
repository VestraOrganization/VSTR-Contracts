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
        usdtAddress: addresses.localhost.USDV,
        tokenAddress: addresses.localhost.VDAOToken,
        nftAddress: addresses.localhost.CMLENFT,
        daoAddress: addresses.localhost.VDAO,
        stakeDaoAddress: addresses.localhost.StakingDAO,

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
        launchTime: LAUNCH_TIME, 
        waitingTime: MONTH_TIME * 3,
        unlockPeriods: MONTH_TIME,
        pool: func.numToParse("1000000000", 18)
    },
    privateSale: {
        contractName: "PrivateSale",
        startTime: PRIVATESALE_START_TIME,
        endTime: PRIVATESALE_START_TIME + (60 * 60 * 24 * 14),
        startVestingTime: LAUNCH_TIME,
        waitingTime: MONTH_TIME * 3,
        unlockPeriods: MONTH_TIME,
        pool: func.numToParse("2000000000", 18)
    },
    stakingDao: {
        contractName: "StakingDAO",
        launchTime: LAUNCH_TIME,
        lockPeriod: MONTH_TIME * 24,
        rewardPeriod: DAY_TIME,
        pool: func.numToParse("1000000000", 18),
    },
    stakingFlexible: {
        contractName: "StakingFlexible",
        launchTime: LAUNCH_TIME,
        rewardPeriod: DAY_TIME,
        pool: func.numToParse("750000000", 18),
    },
    stakingLock: {
        contractName: "StakingLock",
        launchTime: LAUNCH_TIME,
        pool: func.numToParse("750000000", 18),
        penaltySecond: (60 * 60 * 24),
        periods: {
            one: {
                maturity: 1,
                name: "1 Month",
                apr: 4,
                unlockTime: MONTH_TIME,
                poolReward: func.numToParse("1875000", 18),
                maxAccountStake: func.numToParse("500000", 18),
                totalCap: func.numToParse("46875000", 18),
                lateUnStakeFee: (60 * 60 * 24 * 7),
            },
            three: {
                maturity: 3,
                name: "3 Month",
                apr: 8,
                unlockTime: MONTH_TIME * 3,
                poolReward: func.numToParse("5625000", 18),
                maxAccountStake: func.numToParse("750000", 18),
                totalCap: func.numToParse("70312000", 18),
                lateUnStakeFee: (60 * 60 * 24 * 7),
            },
            six: {
                maturity: 6,
                name: "6 Month",
                apr: 12,
                unlockTime: MONTH_TIME * 6,
                poolReward: func.numToParse("11250000", 18),
                maxAccountStake: func.numToParse("1000000", 18),
                totalCap: func.numToParse("93750000", 18),
                lateUnStakeFee: (60 * 60 * 24 * 7 * 2),
            },
            twelve: {
                maturity: 12,
                name: "12 Month",
                apr: 16,
                unlockTime: MONTH_TIME * 12,
                poolReward: func.numToParse("22500000", 18),
                maxAccountStake: func.numToParse("2000000", 18),
                totalCap: func.numToParse("140625000", 18),
                lateUnStakeFee: (60 * 60 * 24 * 7 * 2),
            },
        }
    },
    daoCategories: {
        GameFi: {
            name: "GameFi",
            amount: func.numToParse("4500000000", 18),
            tge: 50,
            cliffTime: MONTH_TIME * 12,
            afterCliffUnlockPerThousand: 100,
            unlockPeriods: MONTH_TIME,
            unlockPerThousand: 10
        },
        Metaverse: {
            name: "Metaverse",
            amount: func.numToParse("4000000000", 18),
            tge: 100,
            cliffTime: MONTH_TIME * 12,
            afterCliffUnlockPerThousand: 300,
            unlockPeriods: MONTH_TIME * 3,
            unlockPerThousand: 30
        },
        Collaborations: {
            name: "Collaborations",
            amount: func.numToParse("2250000000", 18),
            tge: 200,
            cliffTime: MONTH_TIME * 9,
            afterCliffUnlockPerThousand: 50,
            unlockPeriods: MONTH_TIME,
            unlockPerThousand: 50
        },
        Investments: {
            name: "Investments",
            amount: func.numToParse("3750000000", 18),
            tge: 50,
            cliffTime: MONTH_TIME * 6,
            afterCliffUnlockPerThousand: 10,
            unlockPeriods: MONTH_TIME,
            unlockPerThousand: 10 
        },
        Marketing: {
            name: "Marketing",
            amount: func.numToParse("1750000000", 18),
            tge: 100,
            cliffTime: MONTH_TIME * 12,
            afterCliffUnlockPerThousand: 10,
            unlockPeriods: MONTH_TIME, 
            unlockPerThousand: 10 
        },
        Development: {
            name: "Development",
            amount: func.numToParse("1650000000", 18),
            tge: 150, 
            cliffTime: MONTH_TIME * 3,
            afterCliffUnlockPerThousand: 25,
            unlockPeriods: MONTH_TIME,
            unlockPerThousand: 25 
        },
        Charities: {
            name: "Charities",
            amount: func.numToParse("1250000000", 18),
            tge: 0,
            cliffTime: MONTH_TIME * 3,
            afterCliffUnlockPerThousand: 10,
            unlockPeriods: MONTH_TIME, 
            unlockPerThousand: 10 
        },
        Advisors: {
            name: "Advisors",
            amount: func.numToParse("1350000000", 18), 
            tge: 50,
            cliffTime: MONTH_TIME * 3,
            afterCliffUnlockPerThousand: 15,
            unlockPeriods: MONTH_TIME,
            unlockPerThousand: 15
        },
        Treasury: {
            name: "Treasury",
            amount: func.numToParse("10000000000", 18),
            tge: 100, 
            cliffTime: MONTH_TIME * 12, 
            afterCliffUnlockPerThousand: 50, 
            unlockPeriods: MONTH_TIME * 3,
            unlockPerThousand: 50
        },
        Bounties: {
            name: "Bounties",
            amount: func.numToParse("1000000000", 18), 
            tge: 1000,
            cliffTime: 0, 
            afterCliffUnlockPerThousand: 0,
            unlockPeriods: 1,
            unlockPerThousand: 0
        },
        SocialFi: {
            name: "SocialFi",
            amount: func.numToParse("4250000000", 18),
            tge: 1000,
            cliffTime: 0,
            afterCliffUnlockPerThousand: 0,
            unlockPeriods: 1,
            unlockPerThousand: 0
        },


    },
    team: {
        contractName: "Team",
        waitingTime: MONTH_TIME * 12,
        unlockPeriods: MONTH_TIME,
        pool: func.numToParse("7500000000", 18)
    },
    nftIds: holders.nftId,
    nftVote: holders.nftVote,
    nftName: holders.nftName,
    nftOwners: holders.nftOwners,
}
module.exports = { DATA };