// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Interface for the DAO contract.
 */
interface IDAO {
    function holderNFTs(
        address account
    ) external view returns (uint256[] memory); // Represents NFTs held by an account.
}

/**
 * @title VestraTeam Contract
 * @dev Contract managing team members and their claims.
 */
contract VestraTeam {
    event SetMember(address indexed account, uint256 amount, uint64 startTime);
    event ClaimMember(address indexed account, uint256 amount);
    event StatusMember(address indexed account, bool status);

    using Math for uint256;
    using SafeERC20 for IERC20;

    address public token; // Address of the token contract.
    address public nft; // Address of the NFT contract.

    /**
     * @dev Modifier to restrict access to only the boss.
     */
    modifier onlyBoss() {
        uint256[] memory _nfts = IDAO(nft).holderNFTs(msg.sender);
        uint countBoss;
        for (uint i = 0; i < _nfts.length; i++) {
            uint nftId = _nfts[i];
            if (nftId == 1000 || nftId == 2000) {
                countBoss++;
            }
        }
        require(countBoss == 2, "TEAM:You must have a pair of boss NFTs");
        _;
    }

    struct Member {
        uint64 startTime;
        uint256 amount;
        uint256 claimAmount;
        uint64 lastClaimTime;
        bool isActive;
    }
    mapping(address => Member) internal _members;

    uint64 immutable LAUNCH_TIME;
    uint64 immutable WAITING_TIME; 
    uint64 immutable UNLOCK_PERIOD; 
    uint64 constant START_PERCENT = 10; // Percentage of tokens unlocked at the start.
    uint64 constant PERIOD_PERCENT = 1; // Percentage of tokens unlocked in each subsequent period.

    uint256 internal _pool = 7_500_000_000 * 1e18;
    uint256 internal _totalMembersAmount; 
    uint256 internal _totalClaim; 

    /**
     * @dev Constructor to initialize the contract.
     * @param tokenAddress Address of the token contract.
     * @param nftAddress Address of the NFT contract.
     * @param waitingTime Waiting time before the start of unlocking.
     * @param unlockPeriod Time period between each unlock.
     */
    constructor(
        address tokenAddress,
        address nftAddress,
        uint64 waitingTime,
        uint64 unlockPeriod,
        uint64 launchTime
    ) {
        require(
            launchTime > uint64(block.timestamp),
            "launchTime must be greater than current time"
        );
        LAUNCH_TIME = launchTime;
        WAITING_TIME = waitingTime;
        UNLOCK_PERIOD = unlockPeriod;

        token = tokenAddress;
        nft = nftAddress;
    }

    /**
     * @dev Sets a member with a specified amount and start time.
     * @param account Address of the member.
     * @param startTime Start time for unlocking.
     * @param amount Amount of tokens to allocate.
     */
    function setMember(
        address account,
        uint64 startTime,
        uint256 amount
    ) external onlyBoss {
        require(startTime >= LAUNCH_TIME,"Start time must be equals or greater than launch time");
        require(startTime > uint64(block.timestamp),"Start time must be greater than current time");
        Member storage user = _members[account];

        if (user.amount > 0) {
            _totalMembersAmount -= (user.amount - user.claimAmount);
            user.claimAmount = 0;
            user.lastClaimTime = 0;
        }
        require(
            _pool >= _totalMembersAmount + amount, 
            "TEAM:There are not enough tokens in the contract"
        );

        user.amount = amount;
        user.startTime = startTime; 
        user.isActive = true; 

        _totalMembersAmount += amount;

        emit SetMember(account, amount, startTime);
    }

    /**
     * 
     * @param account Address of the member.
     * @param status Activation status of the member. 
     */
    function setStatusMember(address account, bool status) external onlyBoss {
        require(
            _members[account].isActive != status, 
            "TEAM:Already the same status!"
        );
        _members[account].isActive = status;

        emit StatusMember(account, status);
    }

    /**
     * @dev Allows a member to claim their tokens.
     */
    function claim() external {
        address account = msg.sender;
        Member storage user = _members[account];
        require(user.isActive, "TEAM:Your account is not active");
        require(
            user.amount > user.claimAmount,
            "TEAM:All tokens have been claimed"
        );

        uint256 _amount = _calculateClaim(
            user.startTime,
            user.amount,
            user.claimAmount
        );
        require(_amount > 0, "TEAM:There is no claimable amount");
        user.claimAmount += _amount;
        user.lastClaimTime = uint64(block.timestamp);

        if (user.claimAmount >= user.amount) {
            user.isActive = false;
        }
        _totalClaim += _amount;
        SafeERC20.safeTransfer(IERC20(token), account, _amount);
        emit ClaimMember(account, _amount);
    }

    /**
     * @dev Calculates the claimable amount for a member.
     * @param startTime Start time for unlocking.
     * @param amount Total allocated amount.
     * @param claimAmount Amount already claimed.
     * @return uint256 The claimable amount.
     */
    function _calculateClaim(
        uint64 startTime,
        uint256 amount,
        uint256 claimAmount
    ) internal view returns (uint256) {
        uint64 currentTime = uint64(block.timestamp);
        if (currentTime < startTime) {
            return 0;
        }
        uint256 unlockAmount;
        uint64 startPeriodTime = _startPeriodTime(startTime);

        if (currentTime > startTime) {
            unlockAmount += (amount / 100) * START_PERCENT;
        }
        if (currentTime > startPeriodTime) {
            uint period = (currentTime - startPeriodTime) / UNLOCK_PERIOD;
            unlockAmount += ((amount / 100) * PERIOD_PERCENT) * (period + 1);
        }

        return Math.min(unlockAmount, amount) - claimAmount;
    }

    /**
     * @notice Returns information about the contract.
     * @return pool  // Total tokens in the contract.
     * @return totalMembersAmount // Total amount allocated to members.
     * @return totalClaim // Total amount claimed by members.
     * @return waitingTime // Waiting time before the start of unlocking.
     * @return unlockPeriod // Time period between each unlock.
     */
    function info()
        public
        view
        returns (
            uint256 pool,
            uint256 totalMembersAmount,
            uint256 totalClaim,
            uint64 waitingTime,
            uint64 unlockPeriod
        )
    {
        return (
            _pool,
            _totalMembersAmount,
            _totalClaim,
            WAITING_TIME,
            UNLOCK_PERIOD
        );
    }

    /**
     * @notice Returns information about a specific member's account.
     * @param account The address of the account.
     * @return startTime  The start time of the team member.
     * @return amount The total amount of the token team member will receive.
     * @return claimAmount The total amount of the token team member claim.
     * @return unlockAmount The total amount of the token unlocked.
     * @return remaniningAmount Total Remaining Amount of team member.
     * @return lastClaimTime Last claim time.
     * @return nextUnlockAmount Next unlock amount.
     * @return nextUnlockTime Next unlock time.
     * @return isActive is team member active or not.
     */

    function accountInfo(
        address account
    )
        public
        view
        returns (
            uint64 startTime,
            uint256 amount,
            uint256 claimAmount,
            uint256 unlockAmount,
            uint256 remaniningAmount,
            uint64 lastClaimTime, 
            uint256 nextUnlockAmount,
            uint64 nextUnlockTime,
            bool isActive
        )
    {
        Member memory user = _members[account];
        startTime = user.startTime;
        amount = user.amount;
        claimAmount = user.claimAmount;
        lastClaimTime = user.lastClaimTime;
        isActive = user.isActive;
        unlockAmount = _calculateClaim(startTime, amount, claimAmount);
        remaniningAmount = user.amount - (user.claimAmount + unlockAmount);
        (uint64 _nextTime, uint256 _nextAmount) = _nextUnlock(
            startTime,
            amount
        );
        nextUnlockTime = _nextTime;
        nextUnlockAmount = user.amount > user.claimAmount ? _nextAmount : 0;
    }

    /**
     * @dev Calculates the end time for unlocking.
     * @param startTime Start time for unlocking.
     * @return uint64 The end time for unlocking.
     */
    function _endTime(uint64 startTime) internal view returns (uint64) {
        return
            _startPeriodTime(startTime) + (UNLOCK_PERIOD * ((100 - START_PERCENT) - 1));
    }

    /**
     * @dev Calculates the next unlock time and amount.
     * @param startTime Start time for unlocking.
     * @param totalAmount Total allocated amount to the member.
     * @return uint64 The next unlock time.
     * @return uint256 The next unlock amount.
     */
    function _nextUnlock(
        uint64 startTime,
        uint256 totalAmount
    ) internal view returns (uint64, uint256) {

        uint64 currentTime = uint64(block.timestamp);
        uint64 endTime = _endTime(startTime);
        if (currentTime >= endTime || totalAmount == 0) {
            return (0, 0);
        }
        uint256 _amount = (totalAmount / 100) * START_PERCENT;
        if (currentTime < startTime) {
            return (startTime, _amount);
        }
        uint64 startPeriodTime = _startPeriodTime(startTime);
        if (currentTime < startPeriodTime) {
            return (startPeriodTime, (totalAmount / 100) * PERIOD_PERCENT);
        }
        uint64 nextPeriod = ((currentTime - startPeriodTime) / UNLOCK_PERIOD) +
            1;
        uint256 _time = Math.min(
            startPeriodTime + (nextPeriod * UNLOCK_PERIOD),
            endTime
        );

        return (uint64(_time), _amount);
    }

    /**
     * @dev Calculates the start period time.
     * @param startTime Start time for unlocking.
     * @return uint64 The start period time.
     */
    function _startPeriodTime(uint64 startTime) internal view returns (uint64) {
        return startTime + WAITING_TIME;
    }
}
