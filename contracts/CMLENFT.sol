// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


/**
 * @title Interface for the DAO contract.
 */
interface IDAO {
    ///@dev Checks if an NFT is locked.
    function isBlackListNFT(uint256 nftId) external view returns (bool); 
    ///@dev Checks if an account is blacklisted.
    function isBlackListAddress(address account) external view returns (bool); 
    ///@dev Checks if an account is delegate.
    function isDelegate(address account) external view returns (bool); 
    ///@dev Checks election period.
    function isElectionPeriod() external view returns(bool); 
}

/**
 * @title Customizable NFT Contract
 * @dev Contract implementing ERC721 with customizable features like pausing, burning, URI management, etc.
 */
contract CMLENFT is
    ERC721,
    ERC721URIStorage,
    Ownable,
    ERC721Burnable,
    ReentrancyGuard
{

    event MintNFT(uint256 tokenId);
    event SetAddress(address daoAdress);
    event SetUri();

    ///@notice Address of the DAO contract.
    address public dao; 
    ///@dev Mapping of user addresses to their NFTs.
    mapping(address => uint256[]) private _holders; 
    ///@notice Total number of NFTs.
    uint256 public totalSupply; 
    ///@dev Base URI for NFT metadata.
    string private _baseTokenURI; 
    ///@dev Flag to check if NFTs have been created for holders.
    bool private _isCreateHolders; 

    /**
     * @dev Constructor to initialize the contract.
     * @param _initialOwner Address of the initial owner.
     * @param _name Name of the token.
     * @param _symbol Symbol of the token.
     * @param _baseUri Base URI for token metadata.
     */
    constructor(
        address _initialOwner,
        string memory _name,
        string memory _symbol,
        string memory _baseUri
    ) ERC721(_name, _symbol) Ownable(_initialOwner) {
        _baseTokenURI = _baseUri;
    }

    /**
     * @notice Creates NFTs for specified holders.
     * @param recipients Array of recipient addresses.
     * @param nftIds Array of NFT IDs.
     */
    function createHolders(
        address[] memory recipients,
        uint256[] memory nftIds
    ) external onlyOwner {
        require(
            recipients.length == nftIds.length,
            "CMLE:Arrays must have the same length"
        );
        require(!_isCreateHolders, "CMLE:NFTs have been created already");
        for (uint256 i = 0; i < recipients.length; i++) {
            _addNFTToHolder(recipients[i], nftIds[i]);
        }
        totalSupply = nftIds.length;
        _isCreateHolders = true;
    }

    /**
     * @notice Mints NFTs for the caller.
     */
    function mint() external {
        uint256[] storage nftIds = _holders[_msgSender()];
        require(nftIds.length > 0, "CMLE:You have not got NFT");

        bool atLeastOneMinted = false;
        for (uint256 i = 0; i < nftIds.length; i++) {
            uint256 nftId = nftIds[i];
            if (_ownerOf(nftId) == address(0)) {
                _mintNFT(_msgSender(), nftId);
                atLeastOneMinted = true;
            }
        }
        require(atLeastOneMinted, "CMLE:All NFTs are already minted");
    }
 
    /**
     * @notice Delegates cannot transfer their NFTs. In election period NFT transfers are not allowed.
     * @param from Address sending the NFT.
     * @param to Address receiving the NFT.
     * @param tokenId ID of the NFT.
     */
    function transferFrom (
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721, IERC721) nonReentrant {
        require(!isElectionPeriod(), "CMLE:Can not transfer your NFT during the election period"); 
        require(!isDelegate(msg.sender), "CMLE:Delegates cannot transfer their NFTs");
        require(!isBlackListNFT(tokenId), "CMLE:This NFT is locked");
        require(!isBlackListAddress(msg.sender), "CMLE:This wallet is blacklisted");
        require(!isBlackListAddress(from), "CMLE:From wallet is blacklisted");
        require(!isBlackListAddress(to), "CMLE:To wallet is blacklisted");
        super.transferFrom(from, to, tokenId);
        _updateHolders(from, to, tokenId);
    }

    /**
     * @notice Burns an NFT.
     * @param tokenId ID of the NFT to burn.
     */
    function burn (uint256 tokenId) public override nonReentrant {
        require(!isElectionPeriod(), "CMLE:Can not burn token during the election period."); //  
        require(!isBlackListNFT(tokenId), "CMLE:This NFT is locked");
        require(
            tokenId != 1000 || tokenId != 2000,
            "NFT:BOSS NFT cannot be burned"
        );
        super.burn(tokenId);
        totalSupply--;
        _updateHolders(_msgSender(), address(0), tokenId);
    }

    /**
     * @notice Retrieves url it includes information about NFTs.
     * @param tokenId ID of the token.
     * @return string URI for the token.
     */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        require(
            ownerOf(tokenId) != address(0),
            "CMLE:Unknown tokenId"
        );
        return
            string(abi.encodePacked(_baseTokenURI, Strings.toString(tokenId)));
    }

    /**
     * @notice Sets the base URI for all token IDs.
     * @param baseURI The base URI.
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        require(bytes(baseURI).length > 0, "NFT:Base URI cannot be empty");
        _baseTokenURI = baseURI;
        emit SetUri();
    }

    /**
     * @notice Retrieves the NFTs owned by a specific address.
     * @param account Address of the account.
     * @return An array of NFT IDs.
     */
    function holderNFTs(
        address account
    ) external view returns (uint256[] memory) {
        return _holders[account];
    }

    // Internal functions to interact with DAO contract


    /**
     * @notice Checks if an NFT is blacklist.
     * @param nftId ID of the NFT.
     * @return bool Whether the NFT is blacklist.
     */
    function isBlackListNFT(uint256 nftId) public view returns (bool) {
        return IDAO(dao).isBlackListNFT(nftId);
    }

    /**
     * @notice Checks if an account is blacklisted.
     * @param account Address of the account.
     * @return bool Whether the account is blacklisted.
     */
    function isBlackListAddress(address account) public view returns (bool) {
        return IDAO(dao).isBlackListAddress(account);
    }

    /**
     * 
     * @notice Checks if an account is delegate.
     * @param account Address of the account.
     * @return bool Whether the account is delegate.
     */
    function isDelegate(address account) public view returns (bool) {
        return IDAO(dao).isDelegate(account);
    }
    /**
     * 
     * @notice Checks election period.
     * @return bool Whether the election period.
     */
    function isElectionPeriod() public view returns (bool) {
        return IDAO(dao).isElectionPeriod();
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }


    /**
     * @notice Sets addresses for the DAO
     * @param daoAddress Address of the DAO contract.
     */
    function setAddresses(
        address daoAddress
    ) external onlyOwner {
        require(
            daoAddress != address(0),
            "CMLE:DAO address can not be zero."
        );
        dao = daoAddress;
        emit SetAddress(daoAddress); 
    }

    /**
     * @dev Internal function to add an NFT to a holder's collection.
     * @param account Address of the holder.
     * @param tokenId ID of the NFT.
     */
    function _addNFTToHolder(address account, uint256 tokenId) internal {
        _holders[account].push(tokenId);
    }

    /**
     * @dev Internal function to mint an NFT.
     * @param to Address of the recipient.
     * @param tokenId ID of the NFT to mint.
     */
    function _mintNFT(address to, uint256 tokenId) internal {
        require(
            (tokenId >= 1000 && tokenId <= 1250) ||
                (tokenId >= 2000 && tokenId <= 2250),
            "CMLE:Token ID out of the range"
        );
        _mint(to, tokenId);
        emit MintNFT(tokenId);
    }

    /**
     * @dev Internal function to remove an NFT from a holder's collection.
     * @param account Address of the holder.
     * @param tokenId ID of the NFT.
     */
    function _removeNFTFromHolder(address account, uint256 tokenId) internal {
        uint256[] storage _nfts = _holders[account];
        for (uint256 i = 0; i < _nfts.length; i++) {
            if (_nfts[i] == tokenId) {
                _nfts[i] = _nfts[_nfts.length - 1];
                _nfts.pop();
                break;
            }
        }
    }

    /**
     * @dev Internal function to update holder information after transfer.
     * @param from Address of the sender.
     * @param to Address of the recipient.
     * @param tokenId ID of the NFT.
     */
    function _updateHolders(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        _removeNFTFromHolder(from, tokenId);
        _addNFTToHolder(to, tokenId);
    }

}
