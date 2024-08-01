// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
 
// Interface for burning tokens
interface ITokenBurn {
    function burn(uint256 value) external;
}

/**
 * @title StakingLock
 * @dev A contract for staking tokens with locking functionality
 */

contract StakingLock is Ownable, ReentrancyGuard {
    // Events
    event Staked(address indexed user, uint256 amount, uint256 maturity);
    event Unstake(
        address indexed user,
        uint256 amount,
        uint256 maturity,
        uint256 yield,
        uint64 startTime,
        uint256 penaltyAmount
    );

    using SafeERC20 for IERC20;
    // Token address
    address public immutable token;

    // Constants
    uint64 immutable LAUNCH_TIME;
    uint64 immutable PENALTY_SECOND; // penaltı hesaplama süresi

    // Constants for calculations
    uint256 internal constant TOKEN_DECIMAL = 1e18;
    uint256 internal constant MIN_STAKE_AMOUNT = 10_000 * TOKEN_DECIMAL;
    uint256 public poolSize = 750_000_000 * TOKEN_DECIMAL;
    // Modifiers

    /**
     * @dev Modifier to check if maturity exists
     */
    modifier onlyMaturity(uint8 _maturity) {
        require(
            bytes(maturities[_maturity].name).length > 0,
            "STAKE:LOCK:Maturity does not exist"
        );
        _;
    }
    // Auxiliary variable for info functions
    uint8[] maturityItems; 

    // Structs
    struct MaturityData {
        // Constants
        string name;
        uint256 yieldRate;
        uint64 unlockTime; 
        uint256 poolReward; 
        uint256 totalCap; 
        uint256 maxAccountStake; 
        uint64 lateUnStakeFee;
        // Dynamic
        uint256 totalStaked;
        uint256 countUser;
        uint256 totalYield;
        uint256 totalPenalty; 
    }
    struct AccountInfo {
        string name;
        uint64 maturity;
        uint64 startTime;
        uint256 stakeAmount;
        uint256 totalAllocation;
        uint256 penalty;
        uint64 unlockTime;
        bool isClaimed; // unStake yapabilir
    }

    struct Stake {
        uint64 startTime;
        uint256 stakeAmount;
        uint256 yield;
        uint256 penalty;
        uint64 endTime;
        bool isActive;
    }
    // State variables
    mapping(uint8 => MaturityData) maturities;
    mapping(address => mapping(uint8 => Stake)) public stakes;

    /**
     * @dev Constructor to initialize contract parameters
     * @param initialOwner The address of the initial owner.
     * @param tokenAddress The address of the token contract.
     * @param launchTime The timestamp of when staking starts.
     * @param penaltySecond The timestamp of panalty duration.
     */
    constructor(
        address initialOwner,
        address tokenAddress,
        uint64 launchTime,
        uint64 penaltySecond
    ) Ownable(initialOwner) {
        uint64 currentTime = uint64(block.timestamp);
        require(
            initialOwner != address(0),
            "STAKE:LOCK:Owner's address can not be zero."
        );
        require(
            tokenAddress != address(0),
            "STAKE:LOCK:Token address can not be zero."
        );
        require(
            launchTime > currentTime,
            "STAKE:LOCK:Launch time must be greater than present time."
        );

        token = tokenAddress;

        LAUNCH_TIME = launchTime;
        PENALTY_SECOND = penaltySecond;
    }
    // External functions

    /**
     * @notice Function to create a new maturity for staking
     */
    function createMaturityStake(
        uint8 maturity,
        string memory name,
        uint256 yieldRate,
        uint64 unlockTime,
        uint256 poolReward,
        uint256 maxAccountStake,
        uint256 totalCap,
        uint64 lateUnStakeFee
    ) external nonReentrant onlyOwner {
        require(
            bytes(maturities[maturity].name).length == 0,
            "STAKE:LOCK:Maturity already exists"
        );
        MaturityData storage mat = maturities[maturity];

        mat.name = name;
        mat.yieldRate = yieldRate;
        mat.unlockTime = unlockTime;
        mat.poolReward = poolReward;
        mat.maxAccountStake = maxAccountStake;
        mat.totalCap = totalCap;
        mat.lateUnStakeFee = lateUnStakeFee;

        maturityItems.push(maturity);
    }
    /**
     * @notice Function to stake tokens
     */
    function stake(uint256 amount, uint8 maturity) external nonReentrant onlyMaturity(maturity) {
        _stake(_msgSender(), amount, maturity);
    }

    /**
     * @notice Function to stake tokens using permit
     */
    function stakeWithPermit(
        address account,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint8 maturity
    ) external onlyMaturity(maturity) nonReentrant {
        IERC20Permit(address(token)).permit(
            account,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        _stake(account, amount, maturity);
    }

    /**
     * @notice Function to unstake tokens
     */
    function unStake(uint8 maturity) external nonReentrant onlyMaturity(maturity) {
        address account = _msgSender();
        Stake storage user = stakes[account][maturity];
        require(
            user.stakeAmount > 0,
            "STAKE:LOCK:You have no active token lock staking."
        );

        uint64 currentTime = uint64(block.timestamp);

        MaturityData storage data = maturities[maturity];
        require(
            currentTime >= user.startTime + data.unlockTime,
            "STAKE:LOCK:You cannot leave before your time is up."
        );


        uint256 stakeAmount = user.stakeAmount;
        uint256 totalAmount = stakeAmount + user.yield;
        
        uint256 penaltyAmount = _penaltyCalculate(totalAmount, currentTime, user.endTime + data.lateUnStakeFee);
        if(penaltyAmount > 0){
            ITokenBurn(token).burn(penaltyAmount);
            totalAmount -= penaltyAmount;
        }
        

        user.penalty = penaltyAmount;
        user.isActive = false;

        data.totalStaked -= stakeAmount;
        data.countUser--;
        data.totalPenalty += penaltyAmount;

        IERC20(token).safeTransfer(account, totalAmount);

        emit Unstake(account, stakeAmount, maturity, user.yield, user.startTime, penaltyAmount);
    }

    // ------------------------------------------------------------
    // ===================== PUBLIC FUNCTIONS
    // ------------------------------------------------------------
    /**
     * @notice Function to get account information
     */
    function accountInfo(address account) public view returns (AccountInfo[] memory) {
        AccountInfo[] memory userStakes = new AccountInfo[](maturityItems.length);

        uint64 currentTime = uint64(block.timestamp);

        uint256 counter = 0;
        for (uint i = 0; i < maturityItems.length; i++) {
            Stake memory user = stakes[account][maturityItems[i]];

            MaturityData memory data = maturities[maturityItems[i]];
            uint256 yield = _yieldCalculate(user.stakeAmount, data.yieldRate);
            userStakes[counter] = AccountInfo({
                name: data.name,
                maturity: maturityItems[i],
                startTime: user.startTime,
                stakeAmount: user.stakeAmount,
                totalAllocation: user.stakeAmount + yield,
                penalty: !user.isActive ? user.penalty : _penaltyCalculate(user.stakeAmount + yield, currentTime, user.endTime + data.lateUnStakeFee),
                unlockTime: user.endTime,
                isClaimed: user.isActive && user.stakeAmount > 0 && currentTime >= user.endTime ? true : false
                
            });
            counter++;
        }
        return userStakes;
    }
    
    /**
     * @notice Function to get maturity information
     */
    function info() public view returns (MaturityData[] memory) {
        MaturityData[] memory data = new MaturityData[](maturityItems.length);
        for (uint i = 0; i < maturityItems.length; i++) {
            uint8 item = maturityItems[i];
            data[i] = maturities[item];
        }

        return data;
    }
    
    // ------------------------------------------------------------
    // ===================== IMTERNAL FUNCTIONS
    // ------------------------------------------------------------

    /**
     * @dev Function to calculate penalty amount
     */
    function _penaltyCalculate(uint256 amount, uint64 currentTime, uint64 penaltyTime) internal view returns(uint256){
        if(currentTime > penaltyTime){
            uint64 dayPenalty = (currentTime - penaltyTime) / PENALTY_SECOND;
            if(dayPenalty > 75){
                dayPenalty = 75;
            }
            return amount * dayPenalty / 100;
        }
        return 0;
   
    }
    
    /**
     * @dev Function to stake tokens internally
     */
    function _stake(address account, uint256 amount, uint8 maturity) private {
        uint64 currentTime = uint64(block.timestamp);
        require(
            currentTime >= LAUNCH_TIME,
            "STAKE:LOCK:Staking has not started yet"
        );
        require(
            amount >= MIN_STAKE_AMOUNT,
            "STAKE:LOCK:minimum 10,000 stakes must be staked"
        );

        Stake storage user = stakes[account][maturity];
        require(
            !user.isActive,
            "STAKE:LOCK:You have already staked this section"
        );

        MaturityData storage data = maturities[maturity];
        uint256 yield = _yieldCalculate(amount, data.yieldRate);

        require(
            yield <= poolSize,
            "STAKE:LOCK:There is not enough token to meet your reward. Try other stake options."
        );
        
        require(
            amount <= data.maxAccountStake,
            "STAKE:LOCK:Month Stake Maximum Limit per Participant Exceeded"
        );
        require(
            data.totalStaked + amount <= data.totalCap,
            "STAKE:LOCK:The total monthly value of participants exceeds"
        );

        IERC20(token).safeTransferFrom(account, address(this), amount);
        poolSize -= yield;

        data.totalStaked += amount;
        data.countUser++;
        data.totalYield += yield;

        user.startTime = currentTime;
        user.stakeAmount = amount;
        user.yield = yield;
        user.penalty = 0;
        user.endTime = currentTime + data.unlockTime;
        user.isActive = true;

        emit Staked(account, amount, maturity);
    }
    /**
     * @dev Function to calculate yield
     */
    function _yieldCalculate(
        uint256 amount,
        uint256 yieldRate
    ) internal pure returns (uint256) {
        return (amount * yieldRate / 100);
    }
}
