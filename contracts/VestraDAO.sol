// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

// Interface for DAO contract
interface IDAO {
    function isBlackListAddress(address account) external view returns (bool); 
}


contract VestraDAO is
    ERC20,
    ERC20Burnable,
    Ownable,
    ERC20Permit
{
    event SetAddress(address daoAdress);
    // Address of the DAO contract
    address public dao;

    /**
     * @dev Constructor to initialize VDAOToken contract.
     * @param initialOwner Address of the initial owner.
     * @param tokenName Name of the token.
     * @param tokenSymbol Symbol of the token.
     */
    constructor(
        address initialOwner,
        string memory tokenName,
        string memory tokenSymbol
    )
        ERC20(tokenName, tokenSymbol)
        ERC20Permit(tokenName)
        Ownable(initialOwner)
    {
        // Mints initial tokens to the initial owner
        _mint(initialOwner, 50_000_000_000 * 10 ** decimals());
    }

    /**
     * @dev Checks if an account is blacklisted by the DAO.
     * @param account Address to check.
     * @return A boolean indicating whether the account is blacklisted.
     */
    function isBlackList(address account) public view returns (bool) {
        return IDAO(dao).isBlackListAddress(account);
    }

    /**
     * @dev Overrides transfer function to add blacklist check.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            recipient != address(0),
            "VSTR:Cannot transfer to the zero address."
        );
        require(
            amount > 0,
            "VSTR:Transfer amount must be greater than zero."
        );
        require(!isBlackList(_msgSender()), "VSTR:Sender is blacklisted");
        require(!isBlackList(recipient), "VSTR:Recipient is blacklisted");
        return super.transfer(recipient, amount);
    }

    /**
     * @dev Overrides approve function to add blacklist check.
     */
    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        require(
            spender != address(0),
            "VSTR:Cannot approve to the zero address."
        );
        require(
            amount > 0,
            "VSTR:Approval amount must be greater than zero."
        );
        require(!isBlackList(_msgSender()), "VSTR:Account is blacklisted");
        return super.approve(spender, amount);
    }

    /**
     * @dev Overrides transferFrom function to add blacklist check.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            sender != address(0),
            "VSTR:Cannot transfer from the zero address."
        );
        require(
            recipient != address(0),
            "VSTR:Cannot transfer to the zero address."
        );
        require(
            amount > 0,
            "VSTR:Transfer amount must be greater than zero."
        );
        require(!isBlackList(sender), "VSTR:sender is blacklisted");
        require(!isBlackList(recipient), "VSTR:Recipient is blacklisted");
        
        return super.transferFrom(sender, recipient, amount);
    }

    /**
     * @dev Overrides burn function to add blacklist check.
     */
    function burn(uint256 value) public override {
        require(value > 0, "VSTR:Amount to burn should be greater than 0");
        require(
            value <= balanceOf(_msgSender()),
            "VSTR:Not enough tokens to burn"
        );
        require(!isBlackList(_msgSender()), "VSTR:Account is blacklisted");
        super.burn(value);
    }

    /**
     * @dev Overrides burnFrom function to add blacklist check.
     */
    function burnFrom(address account, uint256 value) public override {
        require(
            account != address(0),
            "VSTR:Cannot transfer from the zero address."
        );
        require(value > 0, "VSTR:Amount to burn should be greater than 0");
        require(
            value <= allowance(account, _msgSender()),
            "VSTR:Not enough tokens to burn"
        );
        require(!isBlackList(account), "VSTR:Account is blacklisted");
        super.burnFrom(account, value);
    }

    /**
     * @dev Sets the DAO contract address. Can only be called by the owner.
     * @param daoAddress Address of the DAO contract.
     */
    function setDaoAddress(address daoAddress) external onlyOwner {
        require(
            daoAddress != address(0),
            "VSTR:DAO address can not be zero."
        );
        dao = daoAddress;
        emit SetAddress(daoAddress); 
    }
}
