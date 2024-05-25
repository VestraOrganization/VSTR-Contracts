// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ICMLE Interface
/// @notice Interface for a contract managing a collection of ERC721 tokens.
interface ICMLE is IERC721 {
    /// @notice Returns an array of token IDs owned by the specified address.
    /// @param owner The address to query for owned token IDs.
    /// @return An array of token IDs owned by the specified address.
    function holderNFTs(address owner) external view returns (uint256[] memory);
    function ownerOf(uint256 tokenId) external view returns (address);
}

/// @title VDAOAirdrop Contract
/// @notice Contract for distributing tokens through an airdrop mechanism with vesting.
contract VDAOAirdrop is ReentrancyGuard {

    /// @notice Event emitted when a user claims tokens.
    event Claim(address indexed account, uint256 amount);

    /// @notice Event emitted when a user claims tokens through a partner.
    event ClaimPartners(
        address indexed account,
        address indexed partner,
        uint256 amount
    );

    using SafeERC20 for IERC20;
    using Math for uint256;

    IERC20 public token; // The token being distributed.
    ICMLE public nft; // The contract managing the collection of NFTs.

    // ===================== Airdrop & Vesting  ===================== \\
    uint256 internal constant TOKEN_DECIMAL = 1e18; // Decimal places for token amount.
    uint8 internal constant TGE_RELEASE_PERCENTAGE = 20; // Percentage of tokens released at TGE.
    uint8 internal constant MONTHLY_RELEASE_PERCENTAGE = 4; // Percentage of tokens released monthly.
    uint64 internal immutable WAITING_PERIOD; // Waiting period after vesting starts, 90days.
    uint64 internal immutable UNLOCK_PERIODS; // Number of unlock periods, 30days.
    uint64 internal immutable LAUNCH_TIME; // Timestamp of vesting start.
    uint256 internal constant CMLE_AIRDROP = 1_000_000_000 * TOKEN_DECIMAL; // Total amount for airdrop.
    uint256 internal constant AIRDROP_PER_NFT = 2_000_000 * TOKEN_DECIMAL; // Amount per NFT for airdrop.

    uint256 internal _totalClaimed; // Total tokens claimed so far.

    // Struct to hold airdrop information for a user.
    struct AirdropInfo {
        uint256 totalAmount; // Total amount allocated for the user.
        uint256 receivedAmount; // Amount received by the user.
        uint256 unlockAmount; // Amount unlocked for the user.
        uint256 remainingUnlockAmount; // Remaining amount to unlock for the user.
        uint256 nextUnlockAmount; // Amount to unlock in the next period for the user.
        uint256 nextUnlockTime; // Timestamp of next unlock for the user.
        uint256 lastClaimTime; // Timestamp of last claim by the user.
        bool isCompleted; // Flag indicating if airdrop is completed for the user.
        uint256 maturity; // Timestamp of vesting maturity for the user.
    }

    // Struct to hold airdrop information.
    struct Airdrop {
        uint256 totalAmount; // Total amount allocated for the airdrop.
        uint256 claimAmount; // Amount claimed from the airdrop.
        uint256 lastClaimTime; // Timestamp of last claim from the airdrop.
    }
    ///@dev Mapping of users to airdrop information.
    mapping(address => Airdrop) internal _airdrop;

    ///@notice Mapping of NFT IDs to claimed status.
    mapping(uint256 => bool) public isClaimedNFT; 

    /// @notice Constructor function to initialize the contract.
    /// @param tokenAddress The address of the token contract.
    /// @param nftAddress The address of the NFT contract.
    /// @param launchTime The timestamp of vesting start.
    /// @param waitingTime The waiting period before vesting starts.
    /// @param unlockPeriods The number of unlock periods for vesting.
    constructor(
        address tokenAddress,
        address nftAddress,
        uint64 launchTime,
        uint64 waitingTime,
        uint64 unlockPeriods
    ) {
        uint64 currentTime = uint64(block.timestamp);
        require(
            tokenAddress != address(0),
            "AIRDROP:Token address cannot be zero"
        );
        require(nftAddress != address(0), "AIRDROP:NFT address cannot be zero");
        require(
            launchTime > currentTime,
            "AIRDROP:Launch time must be greater than present time"
        );

        token = IERC20(tokenAddress);
        nft = ICMLE(nftAddress);

        LAUNCH_TIME = launchTime;
        WAITING_PERIOD = waitingTime;
        UNLOCK_PERIODS = unlockPeriods;
    }
    
    /// @notice Returns an array of token IDs owned by the specified address.
    /// @param account The address to query for owned token IDs.
    /// @return An array of token IDs owned by the specified address.
    function holder(address account) public view returns (uint256[] memory) {
        return nft.holderNFTs(account);
    }

    /// @notice Allows the NFT holder to claim their allocated tokens from the airdrop.
    /// @dev Requires vesting to have started and checks if the Holder has any NFTs eligible for the airdrop.
    function claim() external nonReentrant {
        uint64 currentTime = uint64(block.timestamp);
        require(
            currentTime >= LAUNCH_TIME,
            "AIRDROP:Launch time has not started yet"
        );

        address account = msg.sender;
        Airdrop storage user = _airdrop[account];

        uint256 _totalAmount;

        if (user.totalAmount == 0) {
            uint256[] memory nftIds = holder(account);

            require(
                nftIds.length > 0 || user.totalAmount > user.claimAmount,
                "AIRDROP:NFT owner completed right of use"
            );
            uint256 countNft;
            for (uint i = 0; i < nftIds.length; i++) {
                uint256 nftId = nftIds[i];
                if (nftId == 1000 || nftId == 2000) continue; // Exclude BOSS tokens from airdrop
                if(nft.ownerOf(nftId) != account) continue;
                if (isClaimedNFT[nftId]) continue; // Skip NFTs already claimed
                if (!isClaimedNFT[nftId]) {
                    countNft++;
                }
                isClaimedNFT[nftId] = true;
            }
            _totalAmount = countNft * AIRDROP_PER_NFT;
            user.totalAmount = _totalAmount;
        } else {
            _totalAmount = user.totalAmount;
        }

        uint256 amount = _nowUnlockAmount(
            currentTime,
            _totalAmount,
            user.claimAmount
        );
        require(amount > 0, "AIRDROP:Amount to be received is zero");

        user.claimAmount += amount;
        user.lastClaimTime = currentTime;
        _totalClaimed += amount;
        token.safeTransfer(account, amount);

        emit Claim(account, amount);
    }


    /// @notice Calculates the amount of tokens to be unlocked at the current time.
    /// @param currentTime The current timestamp.
    /// @param totalAmount The total allocated amount for the user.
    /// @param claimAmount The amount already claimed by the user.
    /// @return The amount of tokens to be unlocked at the current time.
    function _nowUnlockAmount(
        uint64 currentTime,
        uint256 totalAmount,
        uint256 claimAmount
    ) internal view returns (uint256) {
        uint256 unlockAmount;

        if (currentTime > LAUNCH_TIME) {
            unlockAmount += Math.mulDiv(
                totalAmount,
                TGE_RELEASE_PERCENTAGE,
                100
            );
        }
        uint64 startPeriodTime = _startPeriodTime();
        if (currentTime > startPeriodTime) {
            uint256 _periods = ((currentTime - startPeriodTime) /
                UNLOCK_PERIODS) + 1;
            unlockAmount +=
                Math.mulDiv(totalAmount, MONTHLY_RELEASE_PERCENTAGE, 100) *
                _periods;
        }
        return Math.min(unlockAmount, totalAmount) - claimAmount;
    }

    /// @notice Retrieves the airdrop information for the specified account.
    /// @param account The address of the account to retrieve information for.
    /// @return A struct containing the airdrop information for the specified account.
    function accountInfo(
        address account
    ) external view returns (AirdropInfo memory) {
        Airdrop storage user = _airdrop[account];
        uint256 totalAmount;
        if (user.totalAmount == 0) {
            totalAmount = _airdropCalculate(account);
        } else {
            totalAmount = user.totalAmount;
        }
        uint256 amount = _nowUnlockAmount(
            uint64(block.timestamp),
            totalAmount,
            user.claimAmount
        );
        (uint64 nextTime, uint256 nextAmount) = _nextRewardInfo(totalAmount);
        AirdropInfo memory ai;
        ai.totalAmount = totalAmount; // Total allocated amount
        ai.receivedAmount = user.claimAmount; // Total amount claimed
        ai.unlockAmount = amount; // Amount unlocked (Waiting to be claimed)
        ai.remainingUnlockAmount = totalAmount - (user.claimAmount + amount); // Total amount remaining to be unlocked
        ai.nextUnlockAmount = nextAmount; // Amount for next unlock
        ai.nextUnlockTime = nextTime; // Time for next unlock
        ai.lastClaimTime = user.lastClaimTime; // Timestamp of last claim
        ai.isCompleted = user.claimAmount < totalAmount ? false : true; // Whether all allocations have been claimed

        return ai;
    }

    /// @notice Retrieves general information about the airdrop contract.
    /// @return launchTime The timestamp of vesting start.
    /// @return waitingPeriod The waiting period before vesting starts.
    /// @return unlockPeriods The number of unlock periods for vesting.
    /// @return totalClaimed The total amount of tokens claimed so far.
    function info()
        external
        view
        returns (
            uint64 launchTime,
            uint64 waitingPeriod,
            uint64 unlockPeriods,
            uint256 totalClaimed
        )
    {
        return (LAUNCH_TIME, WAITING_PERIOD, UNLOCK_PERIODS, _totalClaimed);
    }
    /// @dev Retrieves information about the next reward unlock.
    /// @param totalAmount The total allocated amount for the user.
    /// @return nextTime The timestamp of the next reward unlock.
    /// @return nextAmount The amount of tokens to be unlocked at the next reward unlock.
    function _nextRewardInfo(
        uint256 totalAmount
    ) internal view returns (uint64 nextTime, uint256 nextAmount) {
        uint64 currentTime = uint64(block.timestamp);
        if (currentTime < LAUNCH_TIME) {
            nextTime = LAUNCH_TIME;
            nextAmount = Math.mulDiv(totalAmount, TGE_RELEASE_PERCENTAGE, 100);
        } else {
            uint64 startPeriodTime = _startPeriodTime();
            uint64 endPeriodTime = _endPeriodTime();
            if (currentTime < startPeriodTime) {
                nextTime = startPeriodTime;
            } else if (
                currentTime > startPeriodTime && currentTime < endPeriodTime
            ) {
                uint64 nextReward = ((currentTime - startPeriodTime) /
                    UNLOCK_PERIODS) + 1;
                nextTime = startPeriodTime + (nextReward * UNLOCK_PERIODS);
            }
            if (currentTime < endPeriodTime) {
                nextAmount = Math.mulDiv(
                    totalAmount,
                    MONTHLY_RELEASE_PERCENTAGE,
                    100
                );
            }
        }
        return (nextTime, nextAmount);
    }

    /// @dev Retrieves the start time of the first period.
    /// @return The start time of the first period.
    function _startPeriodTime() internal view returns (uint64) {
        return LAUNCH_TIME + WAITING_PERIOD;
    }

    /// @dev Retrieves the total number of periods for vesting.
    /// @return The total number of periods for vesting.
    function _totalPeriods() internal pure returns (uint8) {
        return ((100 - TGE_RELEASE_PERCENTAGE) / MONTHLY_RELEASE_PERCENTAGE);
    }

    /// @dev Retrieves the end time of the last period.
    /// @return The end time of the last period.
    function _endPeriodTime() internal view returns (uint64) {
        return _startPeriodTime() + (UNLOCK_PERIODS * (_totalPeriods() - 1));
    }

    /// @dev Calculates the total amount of tokens to be allocated for the airdrop based on the user's NFT holdings.
    /// @param account The address of the account to calculate the airdrop amount for.
    /// @return The total amount of tokens to be allocated for the airdrop.
    function _airdropCalculate(
        address account
    ) internal view returns (uint256) {
        uint256[] memory nftIds = holder(account);
        require(nftIds.length > 0, "AIRDROP:You have not got NFT");
        uint256 countNft;
        for (uint i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            if (nftId == 1000 || nftId == 2000) continue; // Exclude BOSS tokens from airdrop
            if(nft.ownerOf(nftId) != account) continue;
            if (isClaimedNFT[nftId]) continue; // Skip NFTs already claimed
            if (!isClaimedNFT[nftId]) {
                countNft++;
            }
        }
        return countNft * AIRDROP_PER_NFT;
    }

    // ===================== CMLENFT Airdrop ===================== \\
    //-----------------------------------------------------------------
    // ===================== Partners Airdrops ===================== \\

    uint256 internal constant PARTNER_AD_BOSS_CMHEAD_PERCENTAGE = 15; // Percentage of airdrop for CMHEAD BOSS
    uint256 internal constant PARTNER_AD_BOSS_CMPOWER_PERCENTAGE = 15; // Percentage of airdrop for CMPOWER BOSS
    uint256 internal constant PARTNER_AD_USER_PERCENTAGE = 70; // Percentage of airdrop for HOLDERS

    // ===================== # Partners Airdrops ===================== \\
    ///@notice Amount claimed by users from each partner
    mapping(address => mapping(address => uint256)) public partnersUserClaimAmount; 
    ///@notice Checks that NFT ID is claimed or not.
    mapping(uint256 => mapping(address => bool)) public nftIdPartnerClaimed;
    ///@notice Partner airdrop balances
    mapping(address => uint256) public partnerAirdropBalance; 

    /// @notice Allows the caller to claim their allocated tokens from a specific partner's airdrop.
    /// @param partnerAddress The address of the partner's airdrop contract.
    function partnerAirdropClaim(address partnerAddress) external nonReentrant {
        address account = msg.sender;
        uint256[] memory nftIds = holder(account);

        require(nftIds.length > 0, "AIRDROP:PARTNERS:You have not got NFT");
        require(
            partnersUserClaimAmount[partnerAddress][account] == 0,
            "AIRDROP:PARTNERS:All rights received"
        );

        uint256 partnerBalance;
        if (partnerAirdropBalance[partnerAddress] == 0) {
            partnerBalance = _partnerBalance(partnerAddress);
            partnerAirdropBalance[partnerAddress] = partnerBalance;
        } else {
            partnerBalance = partnerAirdropBalance[partnerAddress];
        }

        require(partnerBalance > 0, "AIRDROP:PARTNERS:No balance for partners");

        uint256 totalAmount = _partnerAirdropCalculate(
            nftIds,
            partnerAddress,
            partnerBalance
        );
        require(totalAmount > 0, "AIRDROP:PARTNERS:Partner has no tokens");

        partnersUserClaimAmount[partnerAddress][account] = totalAmount;

        for (uint i = 0; i < nftIds.length; i++) {
            nftIdPartnerClaimed[nftIds[i]][partnerAddress] = true;
        }

        emit ClaimPartners(account, partnerAddress, totalAmount);

        SafeERC20.safeTransfer(IERC20(partnerAddress), account, totalAmount);
    }

    /// @notice Retrieves the total amount of tokens a user can claim from a specific partner's airdrop.
    /// @param partnerAddress The address of the partner's airdrop contract.
    /// @param account The address of the user.
    /// @return The total amount of tokens the user can claim from the partner's airdrop.
    function partnerAirdropInfo(
        address partnerAddress,
        address account
    ) external view returns (uint256) {
        uint256[] memory nftIds = holder(account);
        if (nftIds.length == 0) {
            return 0;
        }
        uint256 partnerBalance = _partnerBalance(partnerAddress);

        if (partnerBalance > 0) {
            return
                _partnerAirdropCalculate(
                    nftIds,
                    partnerAddress,
                    partnerBalance
                );
        }
        return 0;
    }

    /// @notice Retrieves the balance of tokens allocated for a specific partner's airdrop.
    /// @param partnerAddress The address of the partner's airdrop contract.
    /// @return The balance of tokens allocated for the partner's airdrop.
    function _partnerBalance(
        address partnerAddress
    ) internal view returns (uint256) {
        if (partnerAirdropBalance[partnerAddress] > 0) {
            return partnerAirdropBalance[partnerAddress];
        } else {
            return IERC20(partnerAddress).balanceOf(address(this));
        }
    }

    /// @notice Calculates the total amount of tokens a user can claim from a specific partner's airdrop.
    /// @param nftIds The array of NFT IDs owned by the user.
    /// @param partnerAddress The address of the partner's airdrop contract.
    /// @param amount The total amount of tokens allocated for the partner's airdrop.
    /// @return The total amount of tokens the user can claim from the partner's airdrop.
    function _partnerAirdropCalculate(
        uint256[] memory nftIds,
        address partnerAddress,
        uint256 amount
    ) internal view returns (uint256) {
        uint256 totalAmount;
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            if (!nftIdPartnerClaimed[nftId][partnerAddress]) {
                if (nftId == 1000 || nftId == 2000) {
                    totalAmount += Math.mulDiv(
                        amount,
                        PARTNER_AD_BOSS_CMPOWER_PERCENTAGE,
                        100
                    );
                } else {
                    totalAmount += (Math.mulDiv(
                        amount,
                        PARTNER_AD_USER_PERCENTAGE,
                        100
                    ) / 500);
                }
            }
        }
        return totalAmount;
    }
}
