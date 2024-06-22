// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title StakingFlexible
 * @dev A flexible staking contract where users can stake their tokens and receive rewards.
 */

contract StakingFlexible is Ownable, ReentrancyGuard {
    event Staked(address indexed user, uint256 amount);
    event RecursiveStake(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event UnStake(address indexed owner, uint256 amount, uint256 reward);
    event RemainingClaim(address indexed owner, uint256 amount);
    event IncreasePool(address indexed account, uint256 amount);

    using SafeERC20 for IERC20;
    using Math for uint256;

    IERC20 public immutable token;

    uint256 internal constant RATE_CAL = 1e10;
    uint256 internal constant TOKEN_DECIMAL = 1e18;
    uint256 internal _poolSize;
    uint256 internal constant DAILY_REWARD = 277_777 * TOKEN_DECIMAL;
    uint256 internal _totalStaked;
    uint256 internal _totalClaimedReward;
    uint64 internal _lastUpdateDay;
    uint64 internal immutable LAUNCH_TIME;
    uint64 internal immutable REWARD_PERIOD;
    uint256 internal _countUsers;

    struct Stake {
        uint64 startTime;
        uint256 stakeAmount;
        uint64 epochDay;
        uint64 lastClaimTime;
        uint256 totalClaim;
        bool isActive;
    }
    mapping(address => Stake) internal stakes;

    mapping(uint256 => uint256) internal daysRate;

    /**
     * @dev Initializes the StakingFlexible contract.
     * @param initialOwner The address of the initial owner.
     * @param tokenAddress The address of the staking token.
     * @param launchTime The timestamp when staking starts.
     * @param rewardPeriod The duration of each reward period.
     * @param poolSize The initial size of the reward pool.
     */
    constructor(
        address initialOwner,
        address tokenAddress,
        uint64 launchTime,
        uint64 rewardPeriod,
        uint256 poolSize
    ) Ownable(initialOwner) {
        uint64 currentTime = uint64(block.timestamp);
        require(
            initialOwner != address(0),
            "STAKE:FLEX:Owner's address cannot be zero."
        );
        require(
            tokenAddress != address(0),
            "STAKE:FLEX:Token address cannot be zero."
        );
        require(
            launchTime > currentTime,
            "STAKE:FLEX:Launch time must be greater than present time."
        );

        token = IERC20(tokenAddress);
        LAUNCH_TIME = launchTime;
        REWARD_PERIOD = rewardPeriod;
        _poolSize = poolSize;
    }
    /**
     * @notice Allows a user to stake tokens.
     * @param amount The amount of tokens to stake.
     */
    function stake(uint256 amount) external nonReentrant {
        require(
            token.allowance(_msgSender(), address(this)) >= amount,
            "STAKE:FLEX:Insufficient allowance"
        );
        _stake(_msgSender(), amount);
    }

    /**
     * @notice Allows a user to stake tokens using permit.
     * @param account The account to stake tokens.
     * @param amount The amount of tokens to stake.
     * @param deadline The deadline for permit signature.
     * @param v The `v` component of the permit signature.
     * @param r The `r` component of the permit signature.
     * @param s The `s` component of the permit signature.
     */
    function stakeWithPermit(
        address account,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        IERC20Permit(address(token)).permit(
            account,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        _stake(account, amount);
    }

    /**
     * @notice Allows a user to claim their rewards.
     */
    function claim() external nonReentrant {
        Stake storage user = stakes[_msgSender()];

        require(user.isActive, "STAKE:FLEX:You have none staked tokens.");
        uint64 currentDay = _currentDay();
        _update(currentDay);

        uint256 reward = _calculateReward(
            user.epochDay,
            currentDay,
            user.stakeAmount
        );
        require(reward > 0, "STAKE:FLEX:No reward have been earned yet.");

        user.epochDay = currentDay;
        _claimed(user, reward);
    }

    /**
     * @notice Allows a user to unstake their tokens.
     */
    function unStake() external nonReentrant {
        address account = _msgSender();
        Stake storage user = stakes[account];
        require(user.isActive, "STAKE:FLEX:You have none staked tokens.");

        uint64 currentDay = _currentDay();
        require(
            currentDay >= user.epochDay,
            "STAKE:FLEX:You cannot exit before your is up."
        );

        uint256 amount = user.stakeAmount;
        // kullanıcıya varsa claim haklarınıda ver
        uint256 reward = _calculateReward(
            user.epochDay,
            currentDay,
            user.stakeAmount
        );
        _poolSize -= reward;

        user.epochDay = currentDay;
        user.stakeAmount = 0;
        user.lastClaimTime = uint64(block.timestamp);
        user.totalClaim += reward;
        user.isActive = false;

        _countUsers--;
        _totalClaimedReward += reward;
        _totalStaked -= amount;

        _update(currentDay + 1);
        
        token.safeTransfer(account, amount + reward);

        emit UnStake(account, amount, reward);
    }
    /**
     * @notice Allows a user to stake their rewards.
     */
    
    function rewardToStake() external nonReentrant {
        Stake storage user = stakes[_msgSender()];
        require(user.isActive, "STAKE:FLEX:You have none staked tokens.");
        uint64 currentDay = _currentDay() + 1;
        uint256 reward = _calculateReward(
            user.epochDay,
            currentDay,
            user.stakeAmount
        );
        require(reward > 0, "STAKE:FLEX:No reward have been earned yet.");

        user.stakeAmount += reward;
        user.epochDay = currentDay;

        _totalStaked += reward;
        _totalClaimedReward += reward;

        _update(currentDay);

        emit RecursiveStake(_msgSender(), reward);
    }
    
    /**
     * @notice Allows the contract owner to claim the remaining pool balance after staking ends.
     * @param to The address to transfer the remaining pool balance.
     */
    function remainingClaim(address to) external onlyOwner nonReentrant {
        require(block.timestamp > _endTime(), "STAKE:FLEX:Distribution is still continue.");
        token.safeTransfer(to, _poolSize);
        emit RemainingClaim(to, _poolSize);
    }
    /**
     * @notice Increases the reward pool size.
     * @param amount The amount to increase the reward pool.
     */
    function increasePool(uint256 amount) external {
        token.safeTransferFrom(_msgSender(), address(this), amount);
        _poolSize += amount;
        emit IncreasePool(_msgSender(), amount);
    }

    // ------------------------------------------------------------
    // ===================== PUBLIC FUNCTIONS
    // ------------------------------------------------------------
    /**
     * @notice Retrieves information about a user's staking.
     * @param account The account to query.
     * @return startTime The time when the user started staking.
     * @return stakeAmount The amount of tokens staked by the user.
     * @return lastClaimTime The time of the last claim.
     * @return totalClaim The total amount claimed by the user.
     * @return unlockAmount The amount of rewards available for claim.
     * @return nextUnlockTime The time when the next reward can be claimed.
     * @return nextUnlockAmount The amount of rewards available in the next claim.
     * @return epochDay The current epoch day for the user.
     * @return isActive Whether the user's stake is active.
     */
    function accountInfo(address account) public view returns (
            uint256 startTime,
            uint256 stakeAmount,
            uint256 lastClaimTime,
            uint256 totalClaim,
            uint256 unlockAmount,
            uint256 nextUnlockTime,
            uint256 nextUnlockAmount,
            uint64 epochDay,
            bool isActive
        )
    {
        Stake storage user = stakes[account];

        startTime = user.startTime;
        stakeAmount = user.stakeAmount;
        lastClaimTime = user.lastClaimTime;
        totalClaim = user.totalClaim;
        epochDay = user.epochDay;
        isActive = user.isActive;

        if (user.isActive) {
            uint256 endContractTime = _endTime();
            uint256 currentTime = block.timestamp;

            unlockAmount = _calculateReward(
                user.epochDay,
                _currentDay(),
                user.stakeAmount
            );
            if (endContractTime > currentTime) {
                nextUnlockTime = _nextRewardTime(user.epochDay);
                nextUnlockAmount =
                    (stakeAmount * daysRate[_lastUpdateDay]) /
                    RATE_CAL;
            }
        }
    }
    

    /**
     * @notice Retrieves general information about the staking contract.
     * @return launchTime The time when staking started.
     * @return rewardPeriod The duration of each reward period.
     * @return lastUpdateDay The last day when rate was updated.
     * @return currentDay The day given which day we are in.
     * @return poolSize The current size of the reward pool.
     * @return dailyReward The daily reward amount.
     * @return totalStaked The total amount of tokens staked.
     * @return totalClaimedReward The total amount of tokens claimed as reward.
     * @return userCount The number of active users.
     */
    function info()
        public
        view
        returns (
            uint64 launchTime,
            uint64 rewardPeriod,
            uint64 lastUpdateDay,
            uint64 currentDay,
            uint256 poolSize,
            uint256 dailyReward,
            uint256 totalStaked,
            uint256 totalClaimedReward,
            uint256 userCount
        )
    {
        return (
            LAUNCH_TIME,
            REWARD_PERIOD,
            _lastUpdateDay,
            _currentDay(),
            _poolSize,
            DAILY_REWARD,
            _totalStaked,
            _totalClaimedReward,
            _countUsers
        );
    }
    /**
     * @notice Retrieves the rate for a specific day.
     * @param day The day for which to retrieve the rate.
     * @return The rate for the specified day.
     */
    function getDayRate(uint256 day) public view returns (uint256) {
        uint256 currentDay = day;
        while (true) {
            if (daysRate[currentDay] != 0) {
                return daysRate[currentDay];
            }
            if (currentDay == 0) {
                break;
            }
            currentDay--;
        }
        return 0;
    }


    /**
     * @dev Internal function to handle staking of tokens.
     * @param account The account staking tokens.
     * @param amount The amount of tokens to stake.
     */
    function _stake(address account, uint256 amount) private {
        require(block.timestamp > LAUNCH_TIME, "STAKE:Staking time has not started yet.");
        require(_endTime() > block.timestamp, "STAKE:The contract has expired.");
        require(
            token.balanceOf(account) >= amount,
            "STAKE:FLEX:Insufficient balance."
        );
        token.safeTransferFrom(account, address(this), amount);

        uint64 currentDay = _currentDay() + 1;

        Stake storage user = stakes[account];

        if (user.stakeAmount == 0) {
            user.startTime = uint64(block.timestamp);
            user.isActive = true;
            _countUsers++;
        }

        if (currentDay - 1 >= user.epochDay && user.stakeAmount > 0) {
            uint256 reward = _calculateReward(
                user.epochDay,
                currentDay,
                user.stakeAmount
            );
            _claimed(user, reward);
        }

        user.epochDay = currentDay;
        user.stakeAmount += amount;

        _totalStaked += amount;

        _update(currentDay);
        emit Staked(account, amount);
    }

    /**
     * @dev Internal function to process claiming of rewards.
     * @param user The user claiming rewards.
     * @param reward The amount of rewards to claim.
     */

    function _claimed(Stake storage user, uint256 reward) private {
        user.lastClaimTime = uint64(block.timestamp);
        user.totalClaim += reward;
        _poolSize -= reward;

        address account = _msgSender();
        token.safeTransfer(account, reward);
        _totalClaimedReward += reward;
        emit Claimed(account, reward);

    }

    /**
     * @dev Calculates the total reward for a specific period.
     * @param epochDay The epoch day when staking started.
     * @param claimDay The current epoch day.
     * @param stakeAmount The amount of tokens staked.
     * @return totalReward for the specified period.
     */
    
    function _calculateReward(
        uint64 epochDay,
        uint64 claimDay,
        uint256 stakeAmount
    ) internal view returns (uint256) {
        uint256 totalReward;

        uint256 lastRate;
        for (uint64 i = epochDay; i < claimDay; i++) {
            uint256 dayRate = daysRate[i];
            if (dayRate != 0) {
                lastRate = dayRate;
            }
            totalReward += stakeAmount * lastRate; 
        }
        return totalReward / RATE_CAL;
    }
    /**
     * @dev Updates the contract state for the current day.
     */
    function _update(uint64 day) internal {
        if (_lastUpdateDay <= day) {
            daysRate[day] = _currentRate();
            _lastUpdateDay = day;
        }
    }
    
    /**
     * @dev Calculates the time of the next reward claim.
     * @param epochDay The current epoch day.
     * @return The timestamp of the next reward claim.
     */
    function _nextRewardTime(uint64 epochDay) internal view returns (uint256) {
        uint256 daysPassed = ((block.timestamp - LAUNCH_TIME) / REWARD_PERIOD);
        if (_currentDay() >= epochDay) {
            daysPassed += 1;
        } else {
            daysPassed += 2;
        }
        return LAUNCH_TIME + (daysPassed * REWARD_PERIOD);
    }


    /**
     * @dev Calculates the current rate.
     * @return The current rate.
     */
    function _currentRate() internal view returns (uint256) {
        if(_totalStaked > 0){
            return (DAILY_REWARD * RATE_CAL) / _totalStaked;
        }
        return 0;
    }


    /**
     * @dev Retrieves the current day.
     * @return The current day.
     */
    function _currentDay() internal view returns (uint64) {
        uint64 currentTime = uint64(block.timestamp);
        if (LAUNCH_TIME > currentTime) {
            return 0;
        }
        if (currentTime >= _endTime()) {
            return uint64(_totalPeriod());
        }
        return (currentTime - LAUNCH_TIME) / REWARD_PERIOD;
    }

    /**
     * @dev Calculates the total staking period.
     * @return The total staking period.
     */
    function _totalPeriod() internal view returns (uint256) {
        return ((_poolSize + _totalClaimedReward) / DAILY_REWARD) + 1;
    }


    /**
     * @dev Retrieves the timestamp when staking ends.
     * @return The timestamp when staking ends.
     */
    function _endTime() internal view returns (uint256) {
        return LAUNCH_TIME + (_totalPeriod() * REWARD_PERIOD);
    }
}
