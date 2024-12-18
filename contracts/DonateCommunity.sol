// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract DonateCommunity is Ownable, ReentrancyGuard {

    event Donate(address account, uint256 amount);
    event Withdraw(address indexed owner, uint256 amount);

    using SafeERC20 for IERC20;

    IERC20 public token;
 
    uint256 public totalContribution;

    mapping(address => uint256) public contributors;

    constructor(address initialOwner, address tokenAddress) Ownable(initialOwner) {
        token = IERC20(tokenAddress);
    }

    function donate(uint256 amount) external nonReentrant {
        _addDonate(_msgSender(), amount);
    }

    function donatePermit(
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
        _addDonate(account, amount);
    }

    function _addDonate(address account, uint256 amount) internal {

        token.safeTransferFrom(account, address(this), amount);

        contributors[account] += amount;
        totalContribution += amount;

        emit Donate(account, amount);
    }

    function withdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens available for withdrawal.");
        token.safeTransfer(owner(), balance);

        emit Withdraw(owner(), balance);
    }

}
