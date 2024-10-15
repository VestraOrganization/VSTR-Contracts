// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VestraOTC is Ownable, ReentrancyGuard {

    
    event BuyVSTR(address indexed account, uint256 amount);

    event WithdrawUSDT(address indexed owner, uint256 amount);
    event WithdrawVSTR(address indexed owner, uint256 amount);

    using SafeERC20 for IERC20;

    IERC20 public token;
    IERC20 public usdt;

    // 1 VSTR = 0,01 USDT
    uint256 constant AMOUNT_VSTR = 50_000_000 * 10 ** 18; // 50.000.000 VSTR
    uint256 constant AMOUNT_USDT = 500_000 * 10 ** 6; // 500.000 USDT

    /**
     * @notice Status of participating of OTC
     */
    mapping(address => bool) public buyers;

    /**
     * @notice Number of participants
     */
    uint8 public counterBuyer;

    /**
     * @param initialOwner The initial owner of the contract.
     * @param tokenAddress The address of the token contract.
     * @param usdtAddress The address of the USDT token contract.
     */
    constructor(address initialOwner, address tokenAddress, address usdtAddress) Ownable(initialOwner) {
        require(tokenAddress != address(0) && usdtAddress != address(0), "VSTR or USDT address cannot be zero!");
        token = IERC20(tokenAddress); 
        usdt = IERC20(usdtAddress); 
    }

    /**
     * @notice You must grant spender authorization for the function to work.
     */
    function buy() external nonReentrant {

        require(token.balanceOf(address(this)) >= AMOUNT_VSTR, "No tokens available for sale!");

        address account = _msgSender();

        require(!buyers[account], "Already participated!");

        usdt.safeTransferFrom(account, address(this), AMOUNT_USDT);

        token.safeTransfer(account, AMOUNT_VSTR);

        buyers[account] = true;

        counterBuyer++;

        emit BuyVSTR(account, AMOUNT_VSTR);
    }

    /**
     * @notice Only Owner can call this function
     */
    function withdrawUSDT() external onlyOwner nonReentrant {
        uint256 balance = usdt.balanceOf(address(this));
        require(balance > 0, "No USDT available for withdrawal!");
        usdt.safeTransfer(owner(), balance);

        emit WithdrawUSDT(owner(), balance); 
    }

    /**
     * @notice Only Owner can call this function
     */
    function withdrawVSTR() external onlyOwner nonReentrant{
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No VSTR available for withdrawal!");
        token.safeTransfer(owner(), balance); 

        emit WithdrawVSTR(owner(), balance);  
    }
}
