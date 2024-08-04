// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


interface ICMLE {
    function balanceOf(address _address) external view returns (uint256);
}

/**
 * @title PrivateSale Phase for VSTR
 * @dev A contract for managing a private token sale with vesting.
 */
contract PrivateSale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    event Deposit(address indexed account, uint256 amount);
    event Claim(address indexed account, uint256 amount);
    event Refund(
        address indexed account,
        address indexed sender,
        uint256 amount
    );
    event WithdrawUsdt(address indexed owner, uint256 usdt);
    event WithdrawToken(address indexed owner, uint256 token);
    event Whitelisted(address account, bool status);
    // Modifiers
    modifier onlyWhiteList() {
        require(
            whiteListStatus(_msgSender()),
            "WHITELIST:You are not in the Whitelist"
        );
        _;
    }

    // Constants
    uint256 internal constant RATE = 1e10;
    uint256 internal constant TOKEN_DECIMALS = 1e18;
    uint256 internal constant USDT_DECIMALS = 1e6;

    uint256 internal constant MIN_PURCHASE = 500 * USDT_DECIMALS;
    uint256 internal constant MAX_PURCHASE = 100_000 * USDT_DECIMALS;
    uint256 internal constant TOKEN_PRICE = 500; // 0.0005 USDT
    uint256 internal constant TOTAL_ALLOCATION = 2_000_000_000 * TOKEN_DECIMALS;
    uint256 internal constant TOTAL_EXPECTATION = 1_000_000 * USDT_DECIMALS;
    uint256 internal constant TGE_RELEASE_PERCENTAGE = 10;
    uint256 internal constant MONTHLY_RELEASE_PERCENTAGE = 5;

    // Vesting variables
    uint256 internal immutable START_TIME;
    uint256 internal immutable END_TIME;
    uint256 internal immutable START_VESTING_TIME;
    uint256 internal immutable WAITING_TIME;
    uint256 internal immutable UNLOCK_PERIODS;

    // State variables
    IERC20 public token;
    IERC20 public usdt;
    ICMLE public nft;

    uint256 public withdrawUsdtAmount;
    bool public isWithdrawToken;
    uint256 internal _totalParticipants;
    uint256 internal _totalInvestment;
    uint256 internal _refundedUserCount;
    uint256 internal _totalDistribution;

    struct AccountInfo{
        uint256 deposit;
        uint256 amountRequested;
        uint256 amountReceivedPool;
        uint256 refund;
        uint256 totalClaim;
        uint256 unlockedAmount;
        uint256 restAmount;
        uint256 nextUnlockAmount;
        uint256 nextUnlockTime;
        uint256 lastClaimTime;
        bool isCompleted;
        bool isRefunded;
    }

    struct VestingData {
        uint256 totalAmount;
        uint256 totalClaim;
        uint256 maturityReceived;
        uint256 lastClaimedTime;
        bool isRefunded;
    }

    mapping(address => bool) internal _whitelist;
    mapping(address => uint256) internal _deposits;
    mapping(address => VestingData) internal _vestings;


    /**
     * @dev Constructor to initialize the PrivateSale contract.
     * @param initialOwner The initial owner of the contract.
     * @param usdtAddress The address of the USDT token contract.
     * @param tokenAddress The address of the token contract.
     * @param nftAddress The address of the NFT contract.
     * @param startTime The start time of the private sale.
     * @param endTime The end time of the private sale.
     * @param startVestingTime The start time of vesting.
     * @param waitingTime The waiting period after the first unlock.
     * @param unlockPeriods The duration of each vesting period.
     */
    constructor(
        address initialOwner,
        address usdtAddress,
        address tokenAddress,
        address nftAddress,
        uint256 startTime,
        uint256 endTime,
        uint256 startVestingTime,
        uint256 waitingTime,
        uint256 unlockPeriods
    ) Ownable(initialOwner) {
        require(
            initialOwner != address(0),
            "PSALE:Owner's address cannot be zero"
        );
        require(usdtAddress != address(0), "PSALE:USDT address cannot be zero");
        require(
            tokenAddress != address(0),
            "PSALE:Token address cannot be zero"
        );
        require(nftAddress != address(0), "PSALE:NFT address cannot be zero");
        uint64 currentTime = uint64(block.timestamp);
        require(
            startTime > currentTime,
            "PSALE:Starting Private Sale Time must be in the future"
        );
        require(
            endTime > startTime,
            "PSALE:End time must be after the starting private sale time."
        );
        require(
            startVestingTime > endTime,
            "PSALE:Start Vesting Time must be after the end time."
        );

        token = IERC20(tokenAddress);
        usdt = IERC20(usdtAddress);
        nft = ICMLE(nftAddress);

        START_TIME = startTime; // start private sale
        END_TIME = endTime; // end private sale

        WAITING_TIME = waitingTime;
        UNLOCK_PERIODS = unlockPeriods;
        START_VESTING_TIME = startVestingTime;
    }


    /**
     * @notice Allows whitelisted users to deposit USDT and participate in the private sale.
     * @param usdtAmount The amount of USDT to deposit.
     */
    function buy(uint256 usdtAmount) external onlyWhiteList nonReentrant {
        require(
            block.timestamp >= START_TIME,
            "PSALE:Private Sale is not started"
        );
        require(block.timestamp <= END_TIME, "PSALE:Private Sale completed");
        address account = _msgSender();
        require(
            usdtAmount >= MIN_PURCHASE || _deposits[account] > 0,
            "PSALE:Purchasing amount must be minimum 500 USDT."
        );
        require(
            (_deposits[account] + usdtAmount) <= MAX_PURCHASE,
            "PSALE:You have exceeded the maximum purchase amount"
        );

        usdt.safeTransferFrom(account, address(this), usdtAmount);

        if (_deposits[account] == 0) {
            _totalParticipants++;
        }
        _deposits[account] += usdtAmount;
        _totalInvestment += usdtAmount;
        emit Deposit(account, usdtAmount);
    }

    /**
     * @notice Allows whitelisted users to deposit USDT and participate in the private sale.
     * @param account The address of USDT to deposit.
     */
    function deposit(address account) public view returns (uint256) {
        return _deposits[account];
    }

    /**
     * @notice Allows whitelisted users to claim their vested tokens.
     */
    function claim() external onlyWhiteList nonReentrant {
        uint256 currentTime = block.timestamp;
        require(
            currentTime >= START_VESTING_TIME,
            "PSALE:Distributions have not started yet"
        );
        address account = _msgSender();
        
        VestingData storage user = _vestings[account];
        require(
            user.totalAmount == 0 || user.totalAmount > user.totalClaim,
            "PSALE:All tokens have been claimed"
        );

        if (user.totalAmount == 0) {
            _sendRefund(account);
        }

        (uint256 amount, uint256 maturity) = _calculateClaim(
            user.totalAmount,
            user.lastClaimedTime,
            user.maturityReceived,
            currentTime
        );
        require(amount > 0, "PSALE:No tokens available for claim");

        user.totalClaim += amount;
        user.maturityReceived = maturity;
        user.lastClaimedTime = currentTime;

        token.safeTransfer(account, amount);
        emit Claim(account, amount);
    }


    function refundClaim() external onlyWhiteList nonReentrant {
        require(block.timestamp > END_TIME, "PSALE:Refund time is not started.");
        require(!_vestings[_msgSender()].isRefunded, "PSALE:Refund paid already.");
        _sendRefund(_msgSender());
    }
    
    function _sendRefund(address account) private {
        uint256 userDeposit = _deposits[account];
        require(
            userDeposit > 0,
            "PSALE:You did not participate in the private sale"
        );

        uint256 refundAmount = _refundedUsdt(userDeposit);
        if (refundAmount > 0) {
            usdt.safeTransfer(account, refundAmount);
            emit Refund(account, address(this), refundAmount);
        }
        uint256 calcTotalAmount = _poolAllocation(userDeposit, refundAmount);

        _vestings[account].totalAmount = calcTotalAmount;
        _vestings[account].isRefunded = true;

        _totalDistribution += calcTotalAmount; 
        _refundedUserCount ++;
    }

    function _poolAllocation(uint256 userDeposit, uint256 refundAmount) internal pure returns(uint256){
        return ((userDeposit - refundAmount) * TOKEN_DECIMALS) / TOKEN_PRICE; 
    }
    /**
     * @notice Retrieves information about the specified account.
     * @param account The address of the account.
     */
    function accountInfo(address account) public view returns(
        AccountInfo memory
        ){
            VestingData memory user = _vestings[account];
            AccountInfo memory i;

            uint256 userDeposit = deposit(account);
            uint256 totalAmount;
            if(user.totalAmount > 0){
                totalAmount = user.totalAmount;
            }else{
                uint256 refundAmount = _refundedUsdt(userDeposit);
                totalAmount = _poolAllocation(userDeposit, refundAmount);
            }

            (uint256 amount, uint256 maturity) = _calculateClaim(totalAmount, user.lastClaimedTime, user.maturityReceived, block.timestamp);
            
            i.deposit = userDeposit; // The deposited amount of USDT.          
            i.amountRequested = TOKEN_DECIMALS * (userDeposit / TOKEN_PRICE); // The total amount of tokens requested by the account.           
            i.amountReceivedPool = totalAmount;// The total amount of tokens received from the pool.            
            i.refund = _refundedUsdt(userDeposit); // The amount of USDT to be refunded.            
            i.totalClaim = user.totalClaim;// The total amount of tokens claimed by the account.
            i.unlockedAmount = amount; // The amount of tokens ready to be claimed.
            i.restAmount = (i.amountReceivedPool - user.totalClaim - amount); //The remaining amount of tokens to be unlocked.
            i.nextUnlockAmount = _nextUnlockAmount(i.amountReceivedPool); // The amount of tokens to be unlocked next.
            i.nextUnlockTime = userDeposit > 0 ? _nextUnlockTime(maturity) : 0; // The time of the next token unlock.
            i.lastClaimTime = user.lastClaimedTime; // The time of the last token claim.
            i.isCompleted =  user.totalClaim < i.amountReceivedPool ? false : true; // A boolean indicating whether all tokens have been claimed.
            i.isRefunded = user.isRefunded;
            return i;

    }

    /**
     * @notice Retrieves information about the PrivateSale contract.
     * @return startSaleTime The start time of the private sale.
     * @return endSaleTime The end time of the private sale.
     * @return startVestingTime The start time of vesting.
     * @return waitingTime The waiting time after the first unlock.
     * @return periodsTime The duration of each vesting period.
     * @return totalParticipants The total number of participants.
     * @return totalInvestment The total investment (in USDT).
     */
    function info() public view returns(
        uint256 startSaleTime,
        uint256 endSaleTime,
        uint256 startVestingTime,
        uint256 waitingTime,
        uint256 periodsTime,
        uint256 totalParticipants,
        uint256 totalInvestment
    ){
        return (
            START_TIME,
            END_TIME,
            START_VESTING_TIME,
            WAITING_TIME,
            UNLOCK_PERIODS,
            _totalParticipants,
            _totalInvestment
            );
    }


    /**
     * @notice Withdraw USDT and left tokens from poolsize. only by Owner
     * @param usdtAmount The amount of USDT to withdraw.
     */
    function withdrawUsdt(uint256 usdtAmount) external onlyOwner nonReentrant {
        require(
            block.timestamp > END_TIME,
            "PSALE:withdrawUsdt:Private sale process is still continue."
        );

        require(
            withdrawUsdtAmount + usdtAmount <= TOTAL_EXPECTATION - (TOKEN_PRICE * _totalParticipants),
            "PSALE:withdrawUsdt:Withdraw amount cannot exceed total expectation."
        );

        usdt.safeTransfer(owner(), usdtAmount);

        withdrawUsdtAmount += usdtAmount;

        emit WithdrawUsdt(owner(), usdtAmount);
    }

    /**
     * @notice Withdraw Token only by Owner
     */
    function withdrawToken() external onlyOwner nonReentrant {
        require(
            block.timestamp > END_TIME,
            "PSALE:withdrawToken:Private sale process is still continue."
        );
        require(!isWithdrawToken, "PSALE:You have withdrawn already");

        uint256 rmPoolToken;

        if(_totalInvestment >= TOTAL_EXPECTATION){
            require (_refundedUserCount == _totalParticipants, "PSALE:There is still user that is not claim.");
            rmPoolToken = TOTAL_ALLOCATION - _totalDistribution; 
        }else{
            rmPoolToken = TOTAL_ALLOCATION - (TOKEN_DECIMALS * (_totalInvestment / TOKEN_PRICE)); 
        } 

        // Token transfer process
        token.safeTransfer(owner(), rmPoolToken);

        isWithdrawToken = true;

        emit WithdrawToken(owner(), rmPoolToken);
    }

    /**
     * @notice Adds multiple addresses to the whitelist.
     * @param accounts The addresses to add to the whitelist.
     */
    function whiteListAdd(address[] memory accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _whitelist[accounts[i]] = true;
            emit Whitelisted(accounts[i], true);
        }
    }

    /**
     * @notice Removes an address from the whitelist.
     * @param account The address to remove from the whitelist.
     */
    function whiteListRemove(address account) external onlyOwner {
        _whitelist[account] = false;
        emit Whitelisted(account, false);
    }

    /**
     * @notice Checks the whitelist status of an account.
     * @param account The address of the account.
     * @return status The whitelist status.
     */
    function whiteListStatus(address account) public view returns (bool) {
        return
            _whitelist[account]
                ? true
                : nft.balanceOf(account) > 0
                    ? true
                    : false;
    }

    /**
     * @dev Returns the next unlock amount based on the total amount and current time.
     * @param totalAmount Total amount to unlock.
     * @return uint256 The next unlock amount.
     */
    function _nextUnlockAmount(
        uint256 totalAmount
    ) internal view returns (uint256) {
        uint256 currentTime = block.timestamp;
        if (currentTime < START_VESTING_TIME) {
            // Return the amount to be claimed first
            return _tgeUnlockAmount(totalAmount);
        } else if (
            currentTime >= START_VESTING_TIME && currentTime < _endVestingTime()
        ) {
            // If the current time is after vesting start and before the end of TGE waiting period, return the next unlock amount.
            return _monthlyUnlockAmount(totalAmount);
        } else {
            return 0;
        }
    }

    /**
     * @dev Returns the next unlock time based on the maturity.
     * @param maturity The maturity period.
     * @return uint256 The next unlock time.
     */
    function _nextUnlockTime(uint256 maturity) internal view returns (uint256) {
        uint256 currentTime = block.timestamp;
        uint256 firstMaturity = _firstPeriodTime(); // First installment time
        if (currentTime < START_VESTING_TIME) {
            // If the current time is before vesting start, return the vesting date
            return START_VESTING_TIME;
        } else if (
            currentTime >= START_VESTING_TIME && currentTime < firstMaturity
        ) {
            // If the current time is after vesting start and before the first installment time, return the first maturity
            return firstMaturity;
        } else if (
            currentTime >= firstMaturity && currentTime < _endVestingTime()
        ) {
            // If the current time is after the first maturity and before the end of vesting, calculate the next unlock time
            return firstMaturity + (maturity * UNLOCK_PERIODS);
        } else {
            return 0;
        }
    }

    /**
     * @dev Calculates the claimable amount and maturity based on the total amount, last claimed time, maturity received, and current time.
     * @param totalAmount Total amount to calculate claim from.
     * @param lastClaimedTime Last time claimed.
     * @param maturityReceived Maturity already received.
     * @param currentTime Current time.
     * @return uint256 The claimable amount.
     * @return uint256 The maturity.
     */
    function _calculateClaim(
        uint256 totalAmount,
        uint256 lastClaimedTime,
        uint256 maturityReceived,
        uint256 currentTime
    ) internal view returns (uint256, uint256) {
        uint256 amount;
        uint256 maturity = _currentMaturity(currentTime);

        if (lastClaimedTime == 0 && currentTime >= START_VESTING_TIME) {
            amount += _tgeUnlockAmount(totalAmount);
        }

        amount +=
            (maturity - maturityReceived) *
            _monthlyUnlockAmount(totalAmount);

        return (amount, maturity);
    }

    /**
     * @dev Returns the current maturity based on the current time.
     * @param currentTime Current time.
     * @return uint256 The current maturity.
     */
    function _currentMaturity(
        uint256 currentTime
    ) internal view returns (uint256) {
        uint256 firstPeriodTime = _firstPeriodTime();

        if (currentTime < firstPeriodTime) {
            return 0;
        }

        (, uint256 _gapTime) = Math.trySub(currentTime, firstPeriodTime);
        (, uint256 _maturity) = Math.tryDiv(_gapTime, UNLOCK_PERIODS);
        return Math.min(_maturity + 1, _totalPeriods());
    }

    /**
     * @dev Calculates the refunded USDT amount based on the deposit and the amount.
     * @param _deposit The deposit amount.
     */
    function _refundedUsdt(
        uint256 _deposit
    ) internal view returns (uint256) {
        if (_totalInvestment > TOTAL_EXPECTATION) {
            uint256 poolRate = TOTAL_EXPECTATION * ((_deposit * RATE) / _totalInvestment);
            return (_deposit - (poolRate / RATE));
        }else{
            (, uint256 _refund) = Math.tryMod(_deposit, TOKEN_PRICE);
            return _refund; 
        }
    }


    /**
     * @dev Returns the TGE unlock amount.
     * @param amount The total amount.
     * @return uint256 The TGE unlock amount.
     */
    function _tgeUnlockAmount(uint256 amount) internal pure returns (uint256) {
        return Math.mulDiv(amount, TGE_RELEASE_PERCENTAGE, 100);
    }

    /**
     * @dev Returns the monthly unlock amount.
     * @param amount The total amount.
     * @return uint256 The monthly unlock amount.
     */
    function _monthlyUnlockAmount(
        uint256 amount
    ) internal pure returns (uint256) {
        return Math.mulDiv(amount, MONTHLY_RELEASE_PERCENTAGE, 100);
    }

    /**
     * @dev Returns the first period time.
     * @return uint256 The first period time.
     */
    function _firstPeriodTime() internal view returns (uint256) {
        return START_VESTING_TIME + WAITING_TIME;
    }

    /**
     * @dev Returns the end vesting time.
     * @return uint256 The end vesting time.
     */
    function _endVestingTime() internal view returns (uint256) {
        return
            START_VESTING_TIME +
            WAITING_TIME +
            (UNLOCK_PERIODS * (_totalPeriods() - 1));
    }

    /**
     * @dev Returns the total number of periods.
     * @return uint256 The total number of periods.
     */
    function _totalPeriods() internal pure returns (uint256) {
        return ((100 - TGE_RELEASE_PERCENTAGE) / MONTHLY_RELEASE_PERCENTAGE);
    }
}
