// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RegularWalletWinners
 * @dev A contract that distributes tokens equally to 10 predefined winners.
 * The winners must claim their tokens, and the contract owner has the ability
 * to manage the winners and withdraw tokens in case of an emergency.
 */
contract RegularWalletWinners is Ownable, ReentrancyGuard {

    /// @notice Emitted when a winner successfully claims their reward.
    /// @param account The address of the winner.
    /// @param amount The amount of tokens claimed.
    event Claim(address indexed account, uint256 amount);

    /// @notice Emitted when the owner withdraws remaining tokens from the contract.
    /// @param owner The address of the contract owner.
    /// @param amount The amount of tokens withdrawn.
    event Withdraw(address indexed owner, uint256 amount);

    using SafeERC20 for IERC20;

    /// @notice The token that is distributed as rewards.
    IERC20 public token;

    /// @dev Indicates whether winners have been set.
    bool internal _isSetWinners;

    /// @dev The list of all winners' addresses.
    address[] internal _allWinners;

    /// @dev The reward amount allocated to each winner.
    uint256 internal _reward;

    /// @dev Tracks whether a winner has already claimed their reward.
    mapping (address => bool) internal _isClaimed;

    /**
     * @notice Initializes the contract with the owner and token address.
     * @param initialOwner The initial owner of the contract.
     * @param tokenAddress The address of the ERC20 token contract.
     */
    constructor(address initialOwner, address tokenAddress) Ownable(initialOwner) {
        require(tokenAddress != address(0), "VSTR address cannot be zero!");
        token = IERC20(tokenAddress); 
    }

    /**
     * @notice Sets the list of 10 winners and calculates the reward for each.
     * @dev Can only be called by the contract owner. Each winner will receive an equal share of the contract's balance.
     * @param winners The array of addresses representing the winners.
     */
    function setWinners(address[] memory winners) external onlyOwner() {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens available in the contract.");
        require(winners.length == 10, "Exactly 10 winners must be defined.");
        require(!_isSetWinners, "Winners have already been set.");
        for (uint i = 0; i < winners.length; i++) {
            _allWinners.push(winners[i]);
        }
        _isSetWinners = true;
        _reward = (balance / 10);
    }

    /**
     * @notice Allows a winner to claim their reward.
     * @dev The caller must be a predefined winner and not have claimed their reward before.
     */
    function claim() external nonReentrant{
        address account = _msgSender();
        require(!_isClaimed[account], "You have already claimed your reward.");
        require(_isWinner(account), "You are not one of the winners.");

        _isClaimed[account] = true;
        token.safeTransfer(account, _reward);

        emit Claim(account, _reward);
    }

    /**
     * @notice Allows the owner to withdraw all remaining tokens from the contract in case of an emergency.
     * @dev Can only be called by the contract owner.
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens available for withdrawal.");
        token.safeTransfer(owner(), balance);

        emit Withdraw(owner(), balance);
    }

    /**
     * @notice Provides information about the winners' status and reward amount.
     * @return isSetWinners Whether winners have been set.
     * @return reward The amount of reward allocated to each winner.
     */
    function info() external view returns(bool isSetWinners, uint256 reward) {
        return (_isSetWinners, _reward);
    }

    /**
     * @notice Returns the list of all winners.
     * @return The array of addresses representing the winners.
     */
    function allWinners() external view returns(address[] memory){
        return _allWinners;
    }

    /**
     * @notice Checks if an account is a winner and whether they have claimed their reward.
     * @param account The address to check.
     * @return isWinner Whether the account is a winner.
     * @return isClaim Whether the account has claimed their reward.
     */
    function getWinnerStatus(address account) public view returns(bool isWinner, bool isClaim) {
        return(_isWinner(account), _isClaimed[account]);
    }

    /**
     * @dev Verifies whether an account is one of the predefined winners.
     * @param account The address to check.
     * @return Whether the account is a winner.
     */
    function _isWinner(address account) internal view returns(bool){
        for (uint i = 0; i < _allWinners.length; i++) {
            if(account == _allWinners[i]){
                return true;
            }
        }
        return false;
    }

}
