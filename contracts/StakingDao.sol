// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface ITokenBurn {
    function burnFrom(address account, uint256 value) external;
}

/**
 * @title StakingDAO
 * @dev A contract for staking tokens with DAO features.
 */
contract StakingDAO is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Staked(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 penalty);
    event UnStake(
        address indexed user,
        uint256 reward,
        uint256 amount,
        uint256 penalty
    );
    event AddReward(address indexed user, uint256 amount);
    event RegularWallet(
        address indexed owner,
        uint256 burnAmount,
        uint256 votingPower
    );
    event RemainingClaim(address indexed owner, uint256 amount);
    event IncreasePool(address indexed owner, uint256 amount);

    address public immutable token;


    uint256 constant private RW_BURN_AMOUNT = 10_000 * TOKEN_DECIMAL; // Regular Wallet burn amount
    uint256 internal _rwTotalBurnAmount;

    uint256 internal constant TOKEN_DECIMAL = 1e18;
    uint256 internal constant PRO_WOTING = 200;
    uint256 internal constant REG_WOTING = 1;

    uint64 internal immutable LAUNCH_TIME;
    uint64 internal immutable LOCK_PERIOD; // 2 years 
    uint256 internal constant STAKE_AMOUNT = 2_000_000 * TOKEN_DECIMAL;
    uint256 internal constant PENALTY = 20; // 20% penalty for early withdrawal
    uint256 internal constant DAILY_REWARD = 500_000 * TOKEN_DECIMAL;
    uint64 internal immutable REWARD_PERIOD;

    uint256 internal _poolSize;
    uint256 internal _totalStaked;
    uint256 internal _totalClaimedReward;


    uint64 internal _lastUpdateDay; 

    struct Stake {
        uint64 startTime;
        uint256 lastClaimTime;
        uint256 totalClaim;
        uint64 epochDay;
        bool isActive;
    }
    
    mapping(address => Stake) internal stakes;
    mapping(uint64 => uint256) internal daysUser;

    mapping(address => bool) internal _votingProWallet; // PRO Wallet
    mapping(address => bool) internal _votingRegWallet; // Regular Wallet

    /**
     * @notice Constructor to initialize the StakingDAO contract.
     * @param initialOwner The address of the initial owner.
     * @param tokenAddress The address of the token contract.
     * @param pool The initial size of the reward pool.
     * @param launchTime The timestamp of when staking starts.
     * @param lockPeriod The duration for which staked tokens are locked.
     * @param rewardPeriod The duration of each reward period.
     */
    constructor(
        address initialOwner,
        address tokenAddress,
        uint256 pool,
        uint64 launchTime,
        uint64 lockPeriod,
        uint64 rewardPeriod
    ) Ownable(initialOwner) {
        require(
            initialOwner != address(0),
            "STAKE:PRO:Owner's address cannot be zero."
        );
        require(
            tokenAddress != address(0),
            "STAKE:PRO:Token address cannot be zero."
        );
        require(
            launchTime > uint64(block.timestamp),
            "STAKE:PRO:Launch time must be greater than present time."
        );

        token = tokenAddress;
        // Token will be sent in to contract amount of poolsize.
        _poolSize = pool;
        LAUNCH_TIME = launchTime;
        LOCK_PERIOD = lockPeriod;
        REWARD_PERIOD = rewardPeriod;
    }

    /**
     * @notice Allows a user to stake tokens into the DAO.
     */
    function stake() external nonReentrant {
        address account = _msgSender();
        require(
            IERC20(token).allowance(account, address(this)) >= STAKE_AMOUNT,
            "STAKE:PRO:Insufficient allowance."
        );
        _stake(account);
    }

    /**
     * @notice Allows a user to stake tokens using permit signature.
     * @param account The owner of the tokens. 
     * @param amount The amount of tokens to stake.
     * @param deadline The deadline for the permit signature.
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
    ) external {
        require(
            amount == STAKE_AMOUNT,
            "STAKE:PRO:Exactly 2 milion token must be staked."
        );
        IERC20Permit(token).permit(
            account,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        _stake(account); 
    }
    /**
     * @dev Internal function for staking tokens.
     * @param account Address of the account to stake tokens.
     */
    function _stake(address account) private {
        // Ensure staking time has started
        uint64 currentTime = uint64(block.timestamp);
        require(
            currentTime >= LAUNCH_TIME,
            "STAKE:PRO:Staking time has not started yet."
        );

        // Ensure staking period is still active
        uint64 currentDay = _currentDay();
        require(
            currentDay < _totalPeriod(),
            "STAKE:PRO:All tokens have been distributed."
        );

        // Ensure user has sufficient balance to stake
        require(
            IERC20(token).balanceOf(account) >= STAKE_AMOUNT,
            "STAKE:PRO:Insufficient balance."
        );

        Stake storage user = stakes[account];
        // Ensure user is not already staked
        require(!user.isActive, "STAKE:PRO:Already staked.");

        // Transfer tokens from user to contract
        IERC20(token).safeTransferFrom(account, address(this), STAKE_AMOUNT);

        // Update user stake information
        user.startTime = currentTime;
        user.lastClaimTime = 0;
        user.epochDay = currentDay + 1;
        user.isActive = true;

        // Update global variables
        _votingProWallet[account] = true;
        _totalStaked += STAKE_AMOUNT;
        _update(currentDay + 1);

        emit Staked(account, STAKE_AMOUNT);
    }

    /**
     * @notice Allows a user to claim their rewards.
     */
    function claim() external nonReentrant {
        address account = _msgSender();
        Stake storage user = stakes[account];
        require(user.isActive, "STAKE:PRO:You have none staked tokens.");
        uint64 currentDay = _currentDay();
        _update(currentDay);
        uint256 reward = _calculateReward(user.epochDay, currentDay);
        require(reward > 0, "STAKE:PRO:No reward have been earned yet.");

        user.lastClaimTime = block.timestamp;
        user.totalClaim += reward;
        user.epochDay = currentDay;
        _totalClaimedReward += reward;

        IERC20(token).safeTransfer(account, reward);

        _poolSize -= reward;

        emit Claimed(account, reward);
    }

    /**
     * @notice Unstakes tokens for the sender.
     */
    function unStake() external nonReentrant {
        address account = _msgSender();
        Stake storage user = stakes[account];

        // Ensure user has an active stake
        require(user.isActive, "STAKE:PRO:No active stake");

        uint64 currentTime = uint64(block.timestamp);
        uint64 currentDay = _currentDay();

        // Ensure user cannot unstake before their period is up
        require(
            currentDay >= user.epochDay,
            "STAKE:PRO:You cannot exit before period is up."
        );

        uint256 penaltyAmount;
        if (currentTime < user.startTime + LOCK_PERIOD) {
            penaltyAmount = PENALTY * (STAKE_AMOUNT / 100);
            _poolSize += penaltyAmount;
            emit Withdrawn(account, penaltyAmount);
        }

        uint256 returnAmount = STAKE_AMOUNT - penaltyAmount;

        // Give user any remaining claim rights
        uint256 reward = _calculateReward(user.epochDay, currentDay);
        if (reward > 0) {
            user.totalClaim += reward;
            returnAmount += reward;
            _totalClaimedReward += reward;
            _poolSize -= reward;
        }

        // Update global variables
        _totalStaked -= STAKE_AMOUNT;

        user.lastClaimTime = currentTime;
        user.epochDay = currentDay;
        user.isActive = false;

        _votingProWallet[account] = false;

        // Transfer remaining amount to user
        IERC20(token).safeTransfer(account, returnAmount);

        _update(currentDay + 1);

        emit UnStake(account, reward, returnAmount, penaltyAmount);
    }

    /**
     * @notice In order to lengthen stake contracts time, may increase the staking reward pool.
     * @param amount Stake amount can increase.
     */
    function increasePool(uint256 amount) external nonReentrant {
        IERC20(token).safeTransferFrom(_msgSender(), address(this), amount);
        _poolSize += amount;
        emit IncreasePool(_msgSender(), amount);
    }

    /**
     * @notice Owner can send to account rest amount token after contracts end.
     * @param account Transfer token to account
     */
    function remainingClaim(address account) external onlyOwner nonReentrant {
        require(_currentDay() >= _totalPeriod(), "STAKE:PRO:Distribution is still continue.");
        IERC20(token).safeTransfer(account, _poolSize);
        _poolSize = 0; 
        emit RemainingClaim(account, _poolSize);
    }

    // ------------------------------------------------------------
    // ===================== INTERNAL FUNCTIONS
    // ------------------------------------------------------------
    /**
     * @dev Updates the stake contract for the given day if necessary.
     * @param day The day to update the contract for.
     */
    function _update(uint64 day) internal {
        if (_lastUpdateDay <= day) {
            daysUser[day] = _totalStaked / STAKE_AMOUNT;
            _lastUpdateDay = day;
        }
    }
    /**
     * @dev Calculates the total reward to be distributed between two epoch days.
     * @param epochDay The starting epoch day.
     * @param claimDay The ending epoch day.
     * @return The total reward for the given period.
     */
    function _calculateReward(
        uint64 epochDay,
        uint64 claimDay
    ) internal view returns (uint256) {
        uint256 totalReward;
        uint256 lastUsers;
        for (uint64 i = epochDay; i < claimDay; i++) {
            uint256 dayUser = daysUser[i];
            if (dayUser != 0) {
                lastUsers = dayUser;
            }
            if(lastUsers > 0){
                totalReward += DAILY_REWARD / lastUsers; 
            }
        }
        return totalReward;
    }
    /**
     * @dev Calculates the timestamp for the next reward distribution.
     * @param epochDay The epoch day to calculate the next reward for.
     * @return The timestamp for the next reward distribution.
     */
    function _nextRewardTime(uint64 epochDay) internal view returns (uint256) {
        uint256 daysPassed = (block.timestamp - LAUNCH_TIME) / REWARD_PERIOD;
        if (_currentDay() >= epochDay) {
            daysPassed += 1;
        } else {
            daysPassed += 2;
        }
        return LAUNCH_TIME + (daysPassed * REWARD_PERIOD);
    }
    /**
     * @dev Retrieves the current epoch day.
     * @return The current epoch day.
     */
    function _currentDay() internal view returns (uint64) {
        uint64 currentTime = uint64(block.timestamp);
        if (LAUNCH_TIME > currentTime) {
            return 0;
        }
        if (currentTime >= _endTime()) {
            return _totalPeriod(); 
        }
        return (currentTime - LAUNCH_TIME) / REWARD_PERIOD;
    }
    /**
     * @dev Calculates the total period of the stake contract.
     * @return The total period of the stake contract.
     */
    function _totalPeriod() internal view returns (uint64) { 
        return uint64(((_poolSize + _totalClaimedReward) / DAILY_REWARD) + 1);
    }
    /**
     * @dev Calculates the end timestamp of the stake contract.
     * @return The end timestamp of the stake contract.
     */
    function _endTime() internal view returns (uint64) { 
        return LAUNCH_TIME + (_totalPeriod() * REWARD_PERIOD);
    }

    // ------------------------------------------------------------
    // ===================== PUBLIC FUNCTIONS
    // ------------------------------------------------------------

    /**
     * @notice Retrieves the voting power associated with an account.
     * @param account Address of the account to check.
     * @return The voting power of the account.
     */
    function votingPower(address account) public view returns (uint256) {
        return
            _votingProWallet[account]
                ? PRO_WOTING
                : _votingRegWallet[account]
                    ? REG_WOTING
                    : 0;
    }

    /**
     * @notice Checks if an account is a regular wallet.
     * @param account Address of the account to check.
     * @return A boolean indicating whether the account is a regular wallet.
     */
    function isRegularWallet(address account) public view returns (bool) {
        return _votingRegWallet[account];
    }

    /**
     * @notice Retrieves information about the stake account.
     * @param account Address of the stake account.
     * @return startTime The timestamp when the stake started.
     * @return lastClaimTime The timestamp of the last claim.
     * @return totalClaim Total claimed rewards.
     * @return unlockAmount Amount of rewards available for claiming.
     * @return nextUnlockTime Timestamp of the next reward unlock.
     * @return nextUnlockAmount Amount of rewards to unlock next.
     * @return epochDay The current day of the stake epoch.
     * @return endTime The timestamp when the stake ends.
     * @return power Voting power associated with the account.
     * @return isActive Whether the stake account is active.
     */
    function accountInfo(
        address account
    )
        public
        view
        returns (
            uint256 startTime,
            uint256 lastClaimTime,
            uint256 totalClaim,
            uint256 unlockAmount,
            uint256 nextUnlockTime,
            uint256 nextUnlockAmount,
            uint64 epochDay,
            uint256 endTime,
            uint256 power,
            bool isActive
        )
    {
        Stake memory user = stakes[account];

        startTime = user.startTime;
        lastClaimTime = user.lastClaimTime;
        totalClaim = user.totalClaim;
        epochDay = user.epochDay;
        isActive = user.isActive;

        power = votingPower(account);

        if (user.isActive) {
            unlockAmount = _calculateReward(user.epochDay, _currentDay());
            nextUnlockTime = _nextRewardTime(user.epochDay);
            nextUnlockAmount = DAILY_REWARD / (_totalStaked / STAKE_AMOUNT);
            endTime = user.startTime + LOCK_PERIOD; 
        }
    }


    /**
     * @notice Retrieves general information about the staking contract.
     * @return launchTime Timestamp of the staking contract launch.
     * @return rewardPeriod Duration of each reward period.
     * @return lastUpdateDay Last day the contract was updated.
     * @return currentDay The current day of the staking contract
     * @return poolSize Total size of the staking pool.
     * @return dailyReward The daily reward rate
     * @return totalStaked Total amount of tokens staked.
     * @return totalClaimedReward Total amount of claimed rewards.
     * @return userCount Number of users who have staked.
     * @return rwTotalBurnAmount Total amount burned from regular wallets.
     */
     function info() public view returns(
        uint64 launchTime,
        uint64 rewardPeriod,
        uint64 lastUpdateDay,
        uint64 currentDay,
        uint256 poolSize,
        uint256 dailyReward,
        uint256 totalStaked,
        uint256 totalClaimedReward,
        uint256 userCount,
        uint256 rwTotalBurnAmount
    ){
        return (
            LAUNCH_TIME,
            REWARD_PERIOD, 
            _lastUpdateDay, 
            _currentDay(), 
            _poolSize, 
            DAILY_REWARD,
            _totalStaked, 
            _totalClaimedReward, 
            _totalStaked / STAKE_AMOUNT, 
            _rwTotalBurnAmount
        );
    }

    /**
     * @notice Retrieves the number of users on a specific day.
     * @param day The day for which to retrieve the user count.
     * @return The number of users on the specified day.
     */
    function getDayUser(uint64 day) public view returns(uint256) {

        uint64 currentDay = day;
        while (true) {
            if (daysUser[currentDay] != 0) {
                return daysUser[currentDay];
            }
            if (currentDay == 0) {
                break;
            }
            currentDay--;
        }
        return 0;
    }

    /**
     * @notice Burns tokens from the sender's account and adds voting power.
     */
    function burnRW() public {
        _addVotingPower(_msgSender());
    }

    /**
     * @notice Burns tokens with permit and adds voting power.
     * @param account Address of the account to burn tokens from.
     * @param amount Amount of tokens to burn.
     * @param deadline Expiry timestamp for the permit.
     * @param v Component of the signature.
     * @param r Component of the signature.
     * @param s Component of the signature.
     */
    function burnRWWithPermit(
        address account,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(
            amount == RW_BURN_AMOUNT,
            "STAKE:REGULAR:Exactly 10 thousands token must be staked"
        );
        IERC20Permit(address(token)).permit(
            account,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        _addVotingPower(account);
    }

    /**
     * @dev Adds voting power to an account and emits an event.
     * @param account Address of the account to add voting power to.
     */
    function _addVotingPower(address account) internal {
        ITokenBurn(token).burnFrom(account, RW_BURN_AMOUNT);
        _votingRegWallet[account] = true;
        emit RegularWallet(account, RW_BURN_AMOUNT, REG_WOTING);
        _rwTotalBurnAmount += RW_BURN_AMOUNT;
    }
}
