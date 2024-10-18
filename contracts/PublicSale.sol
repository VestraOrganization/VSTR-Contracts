// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


/**
 * @title Public Sale Phase for VSTR
 * @dev A contract for managing a public token sale with vesting.
 */
contract PublicSale is Ownable, ReentrancyGuard {
    event Deposit(address indexed account, uint256 amount);
    event Claim(address indexed account, uint256 amount);

    event WithdrawUsdt(address indexed owner, uint256 usdt);
    event WithdrawToken(address indexed owner, uint256 token);

    using SafeERC20 for IERC20;
    using Math for uint256;

    IERC20 public token;
    IERC20 public usdt;

    /// @notice isWithdrawToken Withdrawal status of unsold VSTR Tokens by Owner.
    bool public isWithdrawToken;

    uint256 internal _pool;
    uint256 internal _totalSale;

    uint256 internal _totalParticipants;
    uint256 internal _totalInvestment;

    // Constants
    uint256 internal constant TOKEN_DECIMALS = 1e18;
    uint256 internal constant USDT_DECIMALS = 1e6;

    uint256 internal constant MIN_PURCHASE = 50 * USDT_DECIMALS; // 50.00 USDT
    uint256 internal constant MAX_PURCHASE = 1_000 * USDT_DECIMALS; // 1,000.00 USDT
    uint256 internal constant TOKEN_PRICE = 1000; // 0.001 USDT
    uint256 internal constant TGE_RELEASE_PERCENTAGE = 10;
    uint256 internal constant MONTHLY_RELEASE_PERCENTAGE = 5;

    // Vesting variables
    uint256 internal immutable START_TIME;
    uint256 internal immutable END_TIME;
    uint256 internal immutable START_VESTING_TIME;
    uint256 internal immutable CLIFF_TIME;
    uint256 internal immutable UNLOCK_PERIODS;

    /// @title Account Information Data
    /// @notice This structure contains a user's purchase information.
    /// @dev A full description of the fields is provided below.
    struct AccountData {
        /// @notice The amount of USDT deposited by the user (6 decimals)
        uint256 deposit;
        /// @notice Total amount of VSTR purchased
        uint256 totalAmount;
        /// @notice Total amount of VSTR claimed
        uint256 totalClaim;
        /// @notice Last claim time (timestamp)
        uint256 lastClaimTime;
    }

    /// @title The struct of Account Information
    /// @notice This structure contains a user's vesting information.
    /// @dev A full description of the fields is provided below.
    struct AccountInfo {
        /// @notice The amount of USDT deposited by the user (6 decimals)
        uint256 deposit;
        /// @notice Total amount of VSTR purchased
        uint256 totalAmount;
        /// @notice Total amount of VSTR claimed
        uint256 totalClaim;
        /// @notice Last claim time (timestamp)
        uint256 lastClaimTime;
        /// @notice Claimable VSTR amount
        uint256 unlockedAmount;
        /// @notice Sonraki claim miktarı
        uint256 nextUnlockAmount;
        /// @notice Next claimable time
        uint256 nextUnlockTime;
        /// @notice Have all entitlements been received?
        bool isCompleted;
    }

    mapping(address => AccountData) internal _accounts;


    /**
     * @dev Constructor to initialize the public contract.
     * @param initialOwner The initial owner of the contract.
     * @param usdtAddress The address of the USDT token contract.
     * @param tokenAddress The address of the token contract.
     * @param pool The amount of VSTR to sale.
     * @param startTime The start time of the public sale.
     * @param endTime The end time of the public sale.
     * @param startVestingTime The start time of vesting.
     * @param cliffTime The cliff period after the first unlock.
     * @param unlockPeriods The duration of each vesting period.
     */

    constructor(
        address initialOwner,
        address usdtAddress,
        address tokenAddress,
        uint256 pool,
        uint256 startTime,
        uint256 endTime,
        uint256 startVestingTime,
        uint256 cliffTime,
        uint256 unlockPeriods
    ) Ownable(initialOwner) {
        require(
            initialOwner != address(0),
            "Owner's address cannot be zero"
        );
        require(usdtAddress != address(0), "USDT address cannot be zero");
        require(
            tokenAddress != address(0),
            "Token address cannot be zero"
        );
        uint64 currentTime = uint64(block.timestamp);
        require(
            startTime > currentTime,
            "Starting Public Sale Time must be in the future"
        );
        require(
            endTime > startTime,
            "End time must be after the starting Public sale time."
        );
        require(
            startVestingTime > endTime,
            "Start Vesting Time must be after the end time."
        );

        token = IERC20(tokenAddress);
        usdt = IERC20(usdtAddress);
        _pool = pool;

        START_TIME = startTime; // start public sale
        END_TIME = endTime; // end public sale

        CLIFF_TIME = cliffTime;
        UNLOCK_PERIODS = unlockPeriods;
        START_VESTING_TIME = startVestingTime;
    }

    /**
     * @notice Allows users to deposit USDT and participate in the public sale.
     * @param usdtAmount The amount of USDT to deposit.
     */
    function buy(uint256 usdtAmount) external nonReentrant {
        require(
            block.timestamp >= START_TIME,
            "Public Sale is not started"
        );
        require(block.timestamp <= END_TIME, "Public Sale completed");

        AccountData storage user = _accounts[_msgSender()];
        require(
            usdtAmount >= MIN_PURCHASE || user.deposit > 0,
            "Purchasing amount must be minimum 50 USDT."
        );
        require(
            (user.deposit + usdtAmount) <= MAX_PURCHASE,
            "Purchasing amount must be maximum 1000 USDT."
        );

        uint256 buyTokenAmount = _calculate(usdtAmount);

        require(_totalSale + buyTokenAmount <= _pool, "Demanded amount should not exceed the pool!"); 

        usdt.safeTransferFrom(_msgSender(), address(this), usdtAmount);

        if (user.deposit == 0) {
            _totalParticipants++;
        }

        user.deposit += usdtAmount;
        user.totalAmount += buyTokenAmount;

        _totalSale += buyTokenAmount;
        _totalInvestment += usdtAmount;

        emit Deposit(_msgSender(), usdtAmount);
    }

    /**
     * @notice Allows users to claim their vested tokens.
     */
    function claim() external nonReentrant {
        require(
            block.timestamp >= START_VESTING_TIME,
            "Distributions have not started yet!"
        );

        AccountData storage user = _accounts[_msgSender()];
        
        require(user.deposit > 0, "You have not participated Public Sale!");

        uint256 amount = _calculateUnlockAmount(user.totalAmount, user.totalClaim);

        require(amount > 0 && user.totalAmount > user.totalClaim, "Already Claimed!");

        user.totalClaim  += amount;
        user.lastClaimTime = block.timestamp;

        token.safeTransfer(_msgSender(), amount);
        emit Claim(_msgSender(), amount);

    }
    

    /**
     * @notice Retrieves information about the specified account.
     * @param account The address of the account.
     */
    function accountInfo(address account) external view returns(AccountInfo memory){
        AccountData memory user = _accounts[account];
        AccountInfo memory i; 
        i.deposit = user.deposit;
        i.totalAmount = user.totalAmount;
        i.totalClaim = user.totalClaim;
        i.lastClaimTime = user.lastClaimTime;

        i.unlockedAmount = _calculateUnlockAmount(user.totalAmount, user.totalClaim); 
        
        (uint256 amount, uint256 time) = _nextUnlock(user.totalAmount);
        i.nextUnlockAmount = amount; 
        i.nextUnlockTime = time;

        if(user.deposit > 0 && user.totalClaim >= user.totalAmount){
            i.isCompleted = true; 
        }

        return i; 
    }
        
        /**
         * 
         * @return startSaleTime The start time of the public sale.
         * @return endSaleTime The end time of the public sale.
         * @return startVestingTime The start time of vesting.
         * @return cliffTime The waiting time after the first unlock.
         * @return periodsTime The duration of each vesting period.
         * @return totalParticipants The total number of participants.
         * @return totalInvestment The total investment (in USDT)
         * @return pool The total supply for public sale.
         * @return saleAmount Sold VSTR Amount.
         */
    function info() public view
        returns (
            uint256 startSaleTime,
            uint256 endSaleTime,
            uint256 startVestingTime,
            uint256 cliffTime,
            uint256 periodsTime,
            uint256 totalParticipants,
            uint256 totalInvestment,
            uint256 pool,
            uint256 saleAmount
        )
    {
        return (
            START_TIME,
            END_TIME,
            START_VESTING_TIME,
            CLIFF_TIME,
            UNLOCK_PERIODS,
            _totalParticipants,
            _totalInvestment,
            _pool,
            _saleAmount()
        );
    }

    function _saleAmount() internal view returns(uint256){
        return (_totalInvestment * TOKEN_DECIMALS) / TOKEN_PRICE;
    }

    function _calculate(uint256 amount) internal pure returns(uint256){
        return (amount * TOKEN_DECIMALS) / TOKEN_PRICE;
    }

    function _nextUnlock(uint256 totalAmount) internal view returns(uint256 amount, uint256 time){
        if (totalAmount == 0) {
            return (0, 0);
        }
        uint256 currentTime = block.timestamp;

        if(currentTime < START_VESTING_TIME){
            amount = totalAmount * TGE_RELEASE_PERCENTAGE / 100;
            time = START_VESTING_TIME; 
            return (amount, time);
        }

        uint256 startPeriod = _startPeriodTime();
        if (currentTime >= START_VESTING_TIME && currentTime < startPeriod) {
            time = startPeriod;
        }

        if (currentTime >= startPeriod && currentTime < _endVestingTime()) {
            time = startPeriod + (_currentPeriod() * UNLOCK_PERIODS); 
        }

        if(currentTime < _endVestingTime()){
            amount = totalAmount * MONTHLY_RELEASE_PERCENTAGE / 100;
        }
    }

    /**
     * @dev Returns the end vesting time.
     * @return uint256 The end vesting time.
     */
    function _endVestingTime() internal view returns (uint256) {
        return
            START_VESTING_TIME +
            CLIFF_TIME +
            (UNLOCK_PERIODS * (_totalPeriods() - 1));
    }

    /**
     * @dev Returns the total number of periods.
     * @return uint256 The total number of periods.
     */
    function _totalPeriods() internal pure returns (uint256) {
        return ((100 - TGE_RELEASE_PERCENTAGE) / MONTHLY_RELEASE_PERCENTAGE);
    }

    function _calculateUnlockAmount(uint256 totalAmount, uint256 totalClaim) internal view returns(uint256){
        uint256 currentTime = block.timestamp;
        uint256 unlockAmount;

        // Calculate TGE
        if (currentTime >= START_VESTING_TIME) {
            unlockAmount += (totalAmount * TGE_RELEASE_PERCENTAGE) / 100;
        }

        // Calculate periods
        uint256 startPeriod = _startPeriodTime();
        if (currentTime >= startPeriod){
            uint256 periods = ((currentTime - startPeriod) / UNLOCK_PERIODS) + 1;
            unlockAmount += ((totalAmount * MONTHLY_RELEASE_PERCENTAGE) / 100) * periods;
        }

        return _min(unlockAmount, totalAmount) - totalClaim; 
    }


    /**
     * @dev Returns the smallest of two numbers.
     */
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _startPeriodTime() internal view returns(uint256){
        return START_VESTING_TIME + CLIFF_TIME;
    }

    function _currentPeriod() internal view returns(uint256){
        uint256 currentTime = block.timestamp;
        uint256 startMaturity = _startPeriodTime();
        if (currentTime > startMaturity) {
            return ((currentTime - startMaturity) / UNLOCK_PERIODS) + 1;
        }
        return 0; 
    }


    /**
     * @notice Withdraw USDT and left tokens from poolsize. only by Owner
     */
    function withdrawUsdt() external onlyOwner nonReentrant {
        require(
            block.timestamp > END_TIME,
            "Public sale process is still continue."
        );

        uint256 balance = usdt.balanceOf(address(this));

        usdt.safeTransfer(owner(), balance);
        emit WithdrawUsdt(owner(), balance);
    }


    /**
     * @notice Withdraw Token only by Owner
     */
    function withdrawToken() external onlyOwner nonReentrant {
        require(
            block.timestamp > END_TIME,
            "Public sale process is still continue."
        );
        
        require(!isWithdrawToken, "You have withdrawn already");

        uint256 amount = _pool - _totalSale;
        require(amount > 0, "All tokens sold");
        // Token transfer process
        token.safeTransfer(owner(), amount);

        isWithdrawToken = true;

        emit WithdrawToken(owner(), amount);
    }
}
