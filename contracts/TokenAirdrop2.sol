// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenAirdrop2
 * @dev This contract provides a Merkle tree-based airdrop for an ERC20 token.
 * Eligible participants can claim their tokens, with the Merkle tree used
 * to verify their eligibility and prevent unauthorized access.
 */
contract TokenAirdrop2 is Ownable {
    event ClaimAirdrop(address indexed account, uint256 amount);
    event Withdraw(address indexed owner, uint256 amount);

    using SafeERC20 for IERC20;

    /// @notice Address of the VSTR token used in the airdrop.
    address public token;

    /// @notice Root hash of the Merkle tree that defines eligible addresses for the airdrop.
    bytes32 public merkleRoot;

    /// @notice Tracks whether each account has claimed their airdrop.
    mapping(address => bool) public isClaimed;

   /**
     * @dev Constructor sets the initial owner of the airdrop and the token address.
     * @param initialOwner The address that will be the owner of this contract.
     * @param tokenAddress The address of the ERC20 token to be airdropped.
     */
    constructor(address initialOwner, address tokenAddress) Ownable(initialOwner) {
        token = tokenAddress; 
    }

    /**
     * @notice Updates the Merkle root hash for eligibility verification.
     * @dev Can only be called by the contract owner.
     * @param newMerkleRoot The new Merkle root hash.
     */
    function setMerkleRoot(bytes32 newMerkleRoot) public onlyOwner {
        merkleRoot = newMerkleRoot;
    }

    /**
     * @notice Claims a specified amount of tokens from the airdrop.
     * @param _amount The amount of tokens to claim.
     * @param _proof The Merkle proof to verify eligibility.
     */
    function claim(uint256 _amount, bytes32[] calldata _proof) public{
        address account = _msgSender();
        require(!isClaimed[account], "Tokens already claimed.");

        require(_confirmProof(account, _amount, _proof), "Invalid proof.");

        isClaimed[account] = true;
        IERC20(token).safeTransfer(account, _amount);

        emit ClaimAirdrop(account, _amount); 
    }

    /**
     * @notice Checks if a specific account is eligible to claim the airdrop.
     * @param account The address seeking to claim tokens.
     * @param amount The amount of tokens to claim.
     * @param merkleProof The Merkle proof to verify eligibility.
     * @return Returns true if the account is eligible to claim.
     */
    function canClaim(address account, uint256 amount, bytes32[] calldata merkleProof) external view returns (bool) {
        if (isClaimed[account]) {
            return false;
        }
        return _confirmProof(account, amount, merkleProof);
    }

    /**
     * @notice Used by the owner to withdraw all tokens from the contract in case of an emergency.
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 _balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(owner(), _balance);
        emit Withdraw(owner(), _balance);
    }

    function _confirmProof(address account, uint256 amount, bytes32[] calldata merkleProof) internal view returns(bool){
        bytes32 leaf = keccak256(abi.encodePacked(account, amount));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }
}
