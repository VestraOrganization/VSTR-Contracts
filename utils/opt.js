const { ethers, network } = require("hardhat");
const func = require("./funcs")
const addresses = require("../scripts/0000_addresses.json");
const holders = require("./holders");


const PRIVATESALE_START_TIME = func.timestampLocal(2024, 8, 12, 16, 0, 0); // ⚡
const LAUNCH_TIME = func.timestampLocal(2024, 11, 1, 16, 0, 0); // ⚡

const DAY_TIME = (60 * 60 * 24);
const MONTH_TIME = (DAY_TIME * 30);

const networkName = network.name;

const DATA = {
    deploy: {
        ownerAddress: "0x35456BA16043d6DC1D6c4F0AA5df556f54528E31", // ❗
        usdtAddress: addresses[networkName].USDT,
        tokenAddress: addresses[networkName].VestraDAO,
        nftAddress: addresses[networkName].CMLENFT,
        daoAddress: addresses[networkName].VSTRGovernance,
        stakeDaoAddress: addresses[networkName].DAOStaking,

    }, delegate: [
        "0xFB6718ff73885713dC99c8D90Ff56e883A8e5923", // SK Delegate 1 ⚡
        "0xdff28ec657651b447e426ff5385461af1cc4f76b", // IK Delegate 2 ⚡
        "0xfe6e86cE375445e2899457b0E006776295DbB0B8", // EK Delegate 3 ⚡
        "0x271938f0bc383F460fB64d195D331b836546c959", // HK Delegate 4 ⚡
        "0x07Ae058dbB03B57C66D2393040bFDD86dA69f82e", // IKT Delegate 5 ⚡
        "0xA356C1745cadE2c8DD6e02536a673a8013E6993e", // SDT Delegate 6 ⚡
        "0x35456BA16043d6DC1D6c4F0AA5df556f54528E31", // SO Delegate 7 ⚡
    ],
    dao: {
        contractName: "VSTRGovernance",
        launchTime: LAUNCH_TIME,
        electionPeriod: (60 * 60 * 24 * 365 * 3),
        candTime: (60 * 60 * 24 * 10),
        votingTime: (60 * 60 * 24 * 10),
        proposalVotingTime: (60 * 60 * 24 * 3),
        pool: func.numToParse("35750000000", 18),
    },
    USDV: {
        contractName: "USDT",
        name: "USDT Test Token",
        symbol: "USDT",
        decimals: "6"
    },
    token: {
        contractName: "VestraDAO",
        name: "Vestra DAO",
        symbol: "VSTR",
        decimals: "18",
        totalSupply: "50000000000"
    },
    NFT: {
        contractName: "CMLENFT",
        name: "Crypto Monster Limited Edition",
        symbol: "CMLE",
        totalSupply: "502",
        baseURI: "https://nft.cmleteam.com/metadata/"
    },
    airdrop: {
        contractName: "VSTRAirdrop",
        launchTime: LAUNCH_TIME,
        waitingTime: MONTH_TIME * 3,
        unlockPeriods: MONTH_TIME,
        pool: func.numToParse("1000000000", 18)
    },
    privateSale: {
        contractName: "PrivateSale",
        startTime: PRIVATESALE_START_TIME,
        endTime: PRIVATESALE_START_TIME + (60 * 60 * 24 * 10),
        startVestingTime: LAUNCH_TIME,
        waitingTime: MONTH_TIME * 3,
        unlockPeriods: MONTH_TIME,
        pool: func.numToParse("2000000000", 18)
    },
    stakingDao: {
        contractName: "DAOStaking",
        launchTime: LAUNCH_TIME,
        lockPeriod: MONTH_TIME * 24,
        rewardPeriod: DAY_TIME,
        pool: func.numToParse("1000000000", 18),
    },
    stakingFlexible: {
        contractName: "FlexibleStaking",
        launchTime: LAUNCH_TIME,
        rewardPeriod: DAY_TIME,
        pool: func.numToParse("750000000", 18),
    },
    stakingLock: {
        contractName: "LockedStaking",
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
                lateUnStakeFee: (60 * 60 * 24 * 14),
            },
            twelve: {
                maturity: 12,
                name: "12 Month",
                apr: 16,
                unlockTime: MONTH_TIME * 12,
                poolReward: func.numToParse("22500000", 18),
                maxAccountStake: func.numToParse("2000000", 18),
                totalCap: func.numToParse("140625000", 18),
                lateUnStakeFee: (60 * 60 * 24 * 14),
            },
        }
    },
    daoCategories: {
        SocialFi: {
            name: "SocialFi",
            amount: func.numToParse("4250000000", 18),
            tge: 1000,
            cliffTime: 0,
            afterCliffUnlockPerThousand: 0,
            unlockPeriods: 1,
            unlockPerThousand: 0
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
        }
    },
    team: {
        contractName: "VestraTeam",
        waitingTime: MONTH_TIME * 12,
        unlockPeriods: MONTH_TIME,
        pool: func.numToParse("7500000000", 18),
        launchTime: LAUNCH_TIME
    },
    nftIds: holders.nftId,
    nftVote: holders.nftVote,
    nftName: holders.nftName,
    nftOwners: holders.nftOwners,
}
module.exports = { DATA };