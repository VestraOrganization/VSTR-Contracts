// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract RewardPoolLockStaking is Ownable, ReentrancyGuard {

    event PoolLimit(uint256 amount);
    event Contribution(address indexed account, uint256 amount);
    event Withdraw(address indexed owner, uint256 amount);
    event ClaimLockStaking(address indexed owner, uint256 amount);


    using SafeERC20 for IERC20;

    IERC20 public token;
 
    uint256 public totalContribution;
    uint256 public immutable POOL_LIMIT;

    bytes32 public merkleRoot;
    mapping(address => bool) public isClaimed;
    mapping (address => uint) public stakeAccounts;

    constructor(address initialOwner, address tokenAddress, uint256 poolLimit) Ownable(initialOwner) {
        token = IERC20(tokenAddress);
        POOL_LIMIT = poolLimit;
        emit PoolLimit(poolLimit);
    }

    function contribution(uint256 amount) external nonReentrant {
        _stake(_msgSender(), amount);
    }

    function contributionPermit(
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

    function _stake(address account, uint256 amount) internal {
        uint256 balance = token.balanceOf(address(this));

        require(balance < POOL_LIMIT, "Pool limit reached.");

        if (balance + amount >  POOL_LIMIT) {
            amount = POOL_LIMIT - balance;
        }

        token.safeTransferFrom(account, address(this), amount);

        stakeAccounts[account] += amount;
        totalContribution += amount;
        emit Contribution(account, amount);
    }

    function setMerkleRoot(bytes32 newMerkleRoot) external onlyOwner {
        merkleRoot = newMerkleRoot;
    }

    function claimLockStaking(uint256 amount, bytes32[] calldata proof) public {
        address account = _msgSender();
        require(!isClaimed[account], "Tokens already claimed.");

        require(_confirmProof(account, amount, proof), "Invalid proof.");

        isClaimed[account] = true;
        token.safeTransfer(account, amount);

        emit ClaimLockStaking(account, amount);
    }


    function canClaim(address account, uint256 amount, bytes32[] calldata merkleProof) external view returns (bool) {
        if (isClaimed[account]) {
            return false;
        }
        return _confirmProof(account, amount, merkleProof);
    }


    function emergencyWithdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens available for withdrawal.");
        token.safeTransfer(owner(), balance);

        emit Withdraw(owner(), balance);
    }


    function _confirmProof(address account, uint256 amount, bytes32[] calldata merkleProof) internal view returns(bool){
        bytes32 leaf = keccak256(abi.encodePacked(account, amount));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }
}