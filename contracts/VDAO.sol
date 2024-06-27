// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

/**
 * @title DAO Interface
 * @notice Interface for interacting with the DAO contract.
 */
interface INFT  {
    /**
     * @dev Retrieves the NFTs owned by an account.
     * @param account Address of the account.
     * @return uint256[] Array of NFT IDs owned by the account.
     */
    function holderNFTs(
        address account
    ) external view returns (uint256[] memory);

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) external view returns (address); 

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256);
}

interface IToken {
    /**
     * @dev Burns a specific amount of tokens from an account.
     * @param account Address from which to burn tokens.
     * @param value The amount of token to be burned.
     */
    function burnFrom(address account, uint256 value) external; 
    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);  
}

interface IStake {
    /**
     * @dev Retrieves the voting power of an account.
     * @param owner Address of the account.
     * @return uint256 Voting power of the account.
     */
    function votingPower(address owner) external view returns (uint256);
}

/** 
 * @title DAO Mechanism Contract
 * @dev Abstract contract implementing various mechanisms for DAO management.
 */
abstract contract DAOMechanisim is Ownable, ReentrancyGuard {

    event BlacklistedNFT(address indexed account, uint256 tokenId); 
    // Alls vars
    uint8 internal constant SUCCESS_COUNT = 4; // Number of delegates required for a yes vote.

    // Voting Power
    uint256 internal constant VP_BOSS = 100000; // Voting power for boss NFT holders.
    uint256 internal constant VP_USER = 600; // Voting power for regular NFT holders.

    using SafeERC20 for IERC20;

    address public token; // Address of the DAO token contract.
    address public nft; // Address of the NFT contract.
    address public stake; // Address of the staking contract.

    // Election
    uint64 internal immutable LAUNCH_TIME;
    uint64 internal immutable MANAGEMENT_PERIOD; // Duration of the management period for delegates (3 years).
    uint64 internal immutable CANDIDATE_APPLY_TIME; // Duration of the candidate application period.
    uint64 internal immutable CANDIDATE_VOTING_TIME; // Duration of the candidate voting period.
    uint64 internal immutable PROPOSAL_VOTING_TIME; // Duration of the proposal voting period.
    uint256 internal constant BURN_AMOUNT = 10_000 * 1e18; // Burn amount application of delegate
    uint16 internal immutable DELEGATE_COUNT = 7;

    uint64 internal electionTime; // Next election start time

    // dönem => account
    mapping (uint64 => address[]) internal _delegates;
    
    mapping(uint256 => bool) internal _blackListNFT;
    mapping(address => bool) internal _blackListAddress;

    /**
     * @dev Modifier to restrict function access to delegates only.
     */
    modifier onlyDelegate() {
        require(isDelegate(msg.sender), "DAO:Only delegates");
        _;
    }
    /**
     * @dev Modifier to restrict function access to whitelist Address only.
     */
    modifier onlyWhiteListAddress(address account){
        require(!isBlackListAddress(account),"DAO:This wallet is blacklisted"); 
        _;
    }
    /**
     * @dev Modifier to restrict function access to whitelist NFTs only.
     */
    modifier onlyWhiteListNFT(address account){
        uint256[] memory nfts = INFT(nft).holderNFTs(account);
        for (uint i = 0; i < nfts.length; i++) {
            if (isBlackListNFT(nfts[i])) {
                emit BlacklistedNFT(account, nfts[i]);
                revert("DAO:This NFT is on the Blacklist");
            }
        }
        _;
    }


    /**
     * @dev Constructor initializing contract parameters.
     * @param initialOwner Address of the initial contract owner.
     * @param launchTime Time of DAO contract launch.
     * @param electionPeriod Duration of the election period.
     * @param candTime Duration of the candidate application period.
     * @param candVotingTime Duration of the candidate voting period. 
     * @param proposalVotingTime Duration of the proposal voting period.
     */
    constructor(
        address initialOwner,
        uint64 launchTime,
        uint64 electionPeriod,
        uint64 candTime,
        uint64 candVotingTime,
        uint64 proposalVotingTime

    ) Ownable(initialOwner) {
        require(
            launchTime > uint64(block.timestamp),
            "DAO:Staking start time must be greater than present time"
        );
        require(electionPeriod > candTime + candVotingTime, "DAO:Invalid setup");

        LAUNCH_TIME = launchTime;
        electionTime = launchTime + electionPeriod;

        MANAGEMENT_PERIOD = electionPeriod;
        CANDIDATE_APPLY_TIME = candTime;
        CANDIDATE_VOTING_TIME = candVotingTime;
        PROPOSAL_VOTING_TIME = proposalVotingTime;
    }

    /**
     * @notice Retrieves the voting power of an account.
     * @param account Address of the account.
     * @return uint256 Voting power of the account.
     */
    function votingPower(address account) public view returns (uint256) {
        uint256[] memory _nfts = INFT(nft).holderNFTs(account);
        uint256 power;
        for (uint256 i = 0; i < _nfts.length; i++) {
            power += _nftVotingPower(_nfts[i]);
        }

        return power + _stakeVotingPower(account);
    }


    /**
     * @notice Checks if an address has already voted for a delegate.
     * @param _votes Array of addresses representing votes.
     * @param delegate Address of the delegate.
     * @return bool Whether the address has voted for the delegate.
     */
    function isVoted(
        address[] memory _votes,
        address delegate
    ) internal pure returns (bool) {
        for (uint i = 0; i < _votes.length; i++) {
            if (_votes[i] == delegate) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Checks if an address is delegate.
     * @param account Address of the account.
     * @return A boolean indicating whether the address is delegate.
     */    
    function isDelegate(address account) public view returns (bool) {
        uint64 currentPeriod = getCurrentPeriod();
        address[] storage delegates = _delegates[currentPeriod];
        for (uint16 i = 0; i < delegates.length; i++) {
            if(delegates[i] == account){
                return true; 
            }
        }
        return false;
    }

    /**
     * @notice Checks if an address is in the black list.
     * @param account The address to check.
     * @return A boolean indicating whether the address is in the black list.
     */
    function isBlackListAddress(address account) public view returns (bool) {
        return _blackListAddress[account];
    }

    /**
     * @notice Checks if the specified NFT is locked.
     * @param nftId The ID of the NFT to check.
     * @return A boolean indicating whether the NFT is locked.
     */
    function isBlackListNFT(uint256 nftId) public view returns (bool) {
        return _blackListNFT[nftId];
    }

        
    /**
     * @notice Retrieves the current election period.
     * @return uint64 Current election period.
     */
    function getCurrentPeriod() public view returns (uint64) {
        uint64 currentTime = uint64(block.timestamp);
        unchecked {
            if (LAUNCH_TIME > currentTime) return 0;
            return (currentTime - LAUNCH_TIME) / MANAGEMENT_PERIOD;
        }
    }

    /**
     * @notice Retrieves information about DAO parameters.
     * @return launchTime The timestamp of when DAO starts.
     * @return managementPeriod The duration of delegates management time. 
     * @return candidateApplyTime The duration of candidate application time.
     * @return candVotingTime The duration of candidate voting time. 
     * @return proposalVotingTime The duration of proposal voting time.
     */
    function infoDao()
        public
        view
        returns (
            uint64 launchTime,
            uint64 managementPeriod,
            uint64 candidateApplyTime,
            uint64 candVotingTime,
            uint64 proposalVotingTime,
            uint64 electionStartTime
        )
    {
        return (
            LAUNCH_TIME,
            MANAGEMENT_PERIOD,
            CANDIDATE_APPLY_TIME,
            CANDIDATE_VOTING_TIME,
            PROPOSAL_VOTING_TIME,
            electionTime
        );
    }

    /**
     * @notice Retrieves the voting power of an NFT BOSS and Regular NFT Holders.
     * @param nftId ID of the NFT.
     * @return uint256 Voting power of the NFT.
     */
    function _nftVotingPower(uint256 nftId) internal pure returns (uint256) {
        return nftId == 1000 || nftId == 2000 ? VP_BOSS : VP_USER;
    }

    /**
     * @notice Retrieves account voting power who stake pro wallet staking or regular staking.
     * @param account Address of the account.
     * @return uint256 Staking voting power of the account.
     */
    function _stakeVotingPower(address account) internal view returns (uint256) {
        return IStake(stake).votingPower(account);
    }
}

/**
 * @title DAO Categories Contract
 * @dev Abstract contract defining categories for DAO management.
 */
abstract contract DAOCategories is DAOMechanisim {
    // Category Events
    event CreateCategory(address owner, string name, uint256 amount); // Event emitted when a category is created.

    // Category Structure 
    struct Category {
        uint8 id; // Category ID.
        string name; // Category name.
        uint256 budget; // Total budget allocated to the category.
        uint256 unlocked; // Total budget allocated to the category.
        uint256 used; // Amount already used from the category budget.
        uint16 tge; // Percentage of budget to be unlocked at TGE.
        uint64 cliffTime; // Duration to wait after TGE for budget unlocking.
        uint16 cliffRate; // Percentage of budget to be unlocked after cliff.
        uint64 periodTime; // Duration of each unlock period.
        uint16 periodRate; // Percentage of budget to be unlocked in each period.
    }
    mapping(uint8 => Category) internal _categories;
    uint8 internal _categoryId;

    /**
     * @notice Creates a new category.
     * @param name Name of the category.
     * @param amount Total budget allocated to the category.
     * @param tge Percentage of budget to be unlocked at TGE.
     * @param cliffTime Duration to wait after TGE for budget unlocking.
     * @param cliffRate Percentage of budget to be unlocked after cliff.
     * @param periodTime Duration of each unlock period.
     * @param periodRate Percentage of budget to be unlocked in each period.
     */
    function createCategory(
        string memory name,
        uint256 amount,
        uint16 tge,
        uint64 cliffTime,
        uint16 cliffRate,
        uint64 periodTime,
        uint16 periodRate
    ) external onlyOwner {
        require(periodTime > 0, "DAO:CAT:Period time must be greater than zero.");
        Category storage cat = _categories[_categoryId];
        cat.id = _categoryId;
        cat.name = name;
        cat.budget = amount;
        cat.tge = tge;
        cat.cliffTime = cliffTime;
        cat.cliffRate = cliffRate;
        cat.periodTime = periodTime;
        cat.periodRate = periodRate;

        _categoryId++;
        emit CreateCategory(_msgSender(), name, amount);
    }

    /**
     * @notice Retrieves the unlockable amount in a category.
     * @param categoryId ID of the category.
     * @return uint256 Unlockable amount in the category.
     */
    function getCategoryUnlockAmount(
        uint8 categoryId
    ) public view returns (uint256) {
        uint256 unlockAmount;
        uint256 currentTime = block.timestamp;
        Category memory cat = _categories[categoryId];
        uint256 amount = cat.budget;

        if (currentTime >= LAUNCH_TIME) {
            unlockAmount += (amount * cat.tge) / 1000;
        }
        if (currentTime >= LAUNCH_TIME + cat.cliffTime) {
            unlockAmount += (amount * cat.cliffRate) / 1000;
        }
        if (currentTime >= LAUNCH_TIME + cat.cliffTime + cat.periodTime) {
            // periodTime will be sent in to contract when its deployed.
            uint256 _periods = (currentTime - (LAUNCH_TIME + cat.cliffTime)) /
                cat.periodTime;
            unlockAmount += (amount * cat.periodRate * _periods) / 1000;
        }
        return _min(unlockAmount, amount) - cat.used; 
    }

    /**
     * @notice Retrieves information about all categories.
     * @return Category[] Array of all category information.
     */
    function getAllCategoryInfo () external view returns (Category[] memory) {
        Category[] memory cats = new Category[](_categoryId);
        for (uint8 i = 0; i < _categoryId; i++) {
            Category memory cat = _categories[i];
            cat.unlocked = getCategoryUnlockAmount(i);
            cats[i] = cat;
        }
        return cats;
    }

    /**
     * @notice Retrieves information about a specific category.
     * @param categoryId ID of the category.
     * @return Category Information about the category.
     */
    
    function getCategoryIdInfo(
        uint8 categoryId
    ) external view returns (Category memory) {
        return _categories[categoryId];
    }

   /**
     * @dev Returns the smallest of two numbers.
     */
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

/**
 * @title DAOSafeList
 * @dev Contract managing the safe list and blocking of addresses and NFTs within the DAO system. 
 */
abstract contract DAOSafeList is DAOCategories {
    // SafeList Events
    event StatusBlackListAddress(address account, bool status);
    event StatusBlackListNFT(uint256 nftId, bool status);
    event AddSwitchBlackListAddress(address delegate, address account, bool listed);
    event AddSwitchBlackListNFT(address delegate, uint256 nftId, bool listed);

    // BlackList & WhiteList
    struct SwitchBlackListAddress {
        uint256 id;
        uint8 catId;
        uint64 startTime;
        address account;
        address[] votes;
        bool listed;
        bool isCompleted;
    }

    // Block NFT 
    struct SwitchBlackListNFT {
        uint256 id;
        uint8 catId;
        uint64 startTime;
        uint256 nftId;
        address[] votes;
        bool listed;
        bool isCompleted;
    }

    mapping(uint256 => SwitchBlackListAddress) internal _daoBlockAddress;
    mapping(uint256 => SwitchBlackListNFT) internal _daoBlockNFT;

    uint256 public counterBlackListAddress;
    uint256 public counterBlackListNFT;

    /**
     * @notice Adds or removes an address to/from the safe list.
     * @param account The address to add or remove.   
     * @param catId The reason listed of category id.
     * @param listed Whether to add or remove the address (true to add, false to remove).
     */
    function switchBlackListAddress(
        address account,
        uint8 catId,
        bool listed
    ) external onlyDelegate nonReentrant {
        require(
            _blackListAddress[account] != listed, 
            "DAO:BL:Already listed!"
        );

        SwitchBlackListAddress storage prAddress = _daoBlockAddress[counterBlackListAddress];

        prAddress.id = counterBlackListAddress;
        prAddress.account = account;
        prAddress.catId = catId;
        prAddress.startTime = uint64(block.timestamp);
        prAddress.listed = listed;

        prAddress.votes.push(_msgSender());

        counterBlackListAddress++;
        
        emit AddSwitchBlackListAddress(_msgSender(), account, listed);
    }

    /** 
     * @notice Votes for a safe list address proposal.
     * @param id ID of the safe list address proposal to vote for. 
     */
    function voteSwitchBlackListAddress(
        uint256 id
    ) external onlyDelegate nonReentrant {
        uint64 currentTime = uint64(block.timestamp);
        SwitchBlackListAddress storage prAddress = _daoBlockAddress[id];
        require(!prAddress.isCompleted, "DAO:BL:Proposal already completed");
        require(
            currentTime <= prAddress.startTime + PROPOSAL_VOTING_TIME,
            "DAO:BL:Safelist selection expired"
        );
        address delegate = _msgSender();

        require(
            !isVoted(prAddress.votes, delegate),
            "DAO:BL:Already voted"
        );

        prAddress.votes.push(delegate);

        if (prAddress.votes.length >= SUCCESS_COUNT) {
            prAddress.isCompleted = true;
            _blackListAddress[prAddress.account] = prAddress.listed;
            emit StatusBlackListAddress(prAddress.account, prAddress.listed);
        }
    }

    /**
     * @notice Retrieves safe list addresses within a specified range.
     * @param startId Start ID of the safe list addresses.
     * @param endId End ID of the safe list addresses.
     * @return An array of safe list addresses within the specified range. 
     */
    function getBlackListAddressInRange(
        uint256 startId,
        uint256 endId
    ) external view returns (SwitchBlackListAddress[] memory) {
        require(endId > startId, "DAO:Invalid range");
        if (endId > counterBlackListAddress) endId = counterBlackListAddress;
        if (startId > counterBlackListAddress) startId = counterBlackListAddress;

        SwitchBlackListAddress[] memory results = new SwitchBlackListAddress[](
            endId - startId
        );
        uint256 count = 0;
        for (uint256 i = startId; i < endId; i++) {
            results[count] = _daoBlockAddress[i];
            count++;
        }
        return results;
    }

    /**
     * @notice Blacklist address information who created proposal.
     * @param id blacklist proposal id 
     * @return Voting information
     */
    function getBlackListAddressId(uint256 id) public view returns(SwitchBlackListAddress memory){
        return _daoBlockAddress[id]; 
    }


    /**
     * @notice Adds or removes an address to/from the safe list.
     * @param nftId The NFT ID to add or remove.   
     * @param catId The reason listed of category id.
     * @param listed Whether to add or remove the address (true to add, false to remove).
     */
    function switchBlackListNFT(uint256 nftId, uint8 catId, bool listed) external onlyDelegate {
        require(
            _blackListNFT[nftId] != listed, 
            "DAO:BL:Already listed!"
        );

        SwitchBlackListNFT storage prNft = _daoBlockNFT[counterBlackListNFT];

        prNft.id = counterBlackListNFT;
        prNft.nftId = nftId;
        prNft.catId = catId;
        prNft.startTime = uint64(block.timestamp);
        prNft.listed = listed;
        prNft.votes.push(_msgSender());

        counterBlackListNFT++;
        emit AddSwitchBlackListNFT(_msgSender(), nftId, listed);

    }

    /** 
     * @notice Votes for NFT proposal a blacklist or safelist.
     * @param id The ID of the NFT proposal to vote for.
     */
    function voteSwitchBlackListNFT(
        uint256 id
    ) external onlyDelegate nonReentrant {
        uint64 currentTime = uint64(block.timestamp);
        SwitchBlackListNFT storage prNft = _daoBlockNFT[id];
        require(!prNft.isCompleted, "DAO:BL:Proposal already completed");
        require(
            currentTime <= prNft.startTime + PROPOSAL_VOTING_TIME,
            "DAO:NFT:Selection expired"
        );
        address delegate = _msgSender();

        require(!isVoted(prNft.votes, delegate), "DAO:BL:Already voted");

        prNft.votes.push(delegate); 

        if (prNft.votes.length >= SUCCESS_COUNT) {
            prNft.isCompleted = true;
            _blackListNFT[prNft.nftId] = prNft.listed;
           
            emit StatusBlackListNFT(prNft.nftId, prNft.listed);
        }
    }

    /**
     * @notice Retrieves safe list NFTs within a specified range.
     * @param startId Start ID of the safe list NFTs.
     * @param endId End ID of the safe list NFTs.
     * @return An array of safe list NFTs within the specified range. 
     */
    function getBlackListNftInRange(
        uint256 startId,
        uint256 endId
    ) external view returns (SwitchBlackListNFT[] memory) {
        require(endId > startId, "DAO:Invalid range");
        if (endId > counterBlackListNFT) endId = counterBlackListNFT;
        if (startId > counterBlackListNFT) startId = counterBlackListNFT;

        SwitchBlackListNFT[] memory results = new SwitchBlackListNFT[](
            endId - startId
        );
        uint256 count = 0;
        for (uint256 i = startId; i < endId; i++) {
            results[count] = _daoBlockNFT[i];
            count++;
        }
        return results;
    }

    function getBlackListNFTId(uint256 id) public view returns(SwitchBlackListNFT memory){
        return _daoBlockNFT[id];
    }
}

/**
 * @title DAO Delegates Contract
 * @dev Abstract contract implementing delegate application, voting, and election mechanisms. 
 */
abstract contract DAODelegates is DAOSafeList {

    event CandidateApply(address account);
    event VoteCandidate(address account, address delegate);
    event ElectionEnded();     

    struct Candidates{
        address account; 
        uint256 voting;
    }

    /// @notice List candidates of Election for specific period.
    mapping (uint64 => mapping(uint16 => Candidates)) internal candidatesOfElection;
    /// @notice Count candidates of Election for specific period.
    mapping (uint64 => uint16) public candidateCounter;

    /// @notice Is NFT voted or not
    
    mapping (uint64 => mapping(uint256 => bool)) public isVotedNFT;
    /// @notice Is Prowallet voted or not
    mapping (uint64 => mapping(address => bool)) public isVotedAddress; 
    ///@notice Calculate used voting power in election for specific period.
    mapping (uint64 => mapping(address => uint256)) public usedVotingPower;


    /**
     * @dev Only NFTs holder who is not in blacklisted can apply.
     * @notice To become a candidate you must approve 10000 tokens to be spent on the DAO contract.
     */
    function candidateApply() external nonReentrant  {
        _saveCandidateOfDelegate(_msgSender());
    }

    function candidateApplyPermit(
        address account,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        require(
            amount == BURN_AMOUNT,
            "DAO:DLG:Only 10,000 tokens can be sent for burning."
        );
        IERC20Permit(address(token)).permit(
            account,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
        _saveCandidateOfDelegate(account);
    }
    
    function _saveCandidateOfDelegate(address account) private onlyWhiteListAddress(account) onlyWhiteListNFT(account){
        uint64 currentTime = uint64(block.timestamp);

        require(currentTime > electionTime && currentTime < _candidateApplicationEnd(),"DAO:DLG:We are not in candidate application period!");
        uint64 currentPeriod = getCurrentPeriod();
        uint16 candidateCount = candidateCounter[currentPeriod];

        for (uint16 i = 0; i < candidateCounter[currentPeriod]; i++) {
            require(candidatesOfElection[currentPeriod][i].account != account, "DAO:DLG:Already applied!");
        }

        IToken(token).burnFrom(account, BURN_AMOUNT);

        candidatesOfElection[currentPeriod][candidateCount].account = account;

        candidateCounter[currentPeriod]++;
        emit CandidateApply(account);
    }

    /**
     * @notice Pro (200VP) & regular (1VP) wallets and NFT (600VP) holders can vote only.
     * @param candidateAccount Address you want to vote.
     */
    function voteToCandidate (address candidateAccount) external nonReentrant {
        address account = _msgSender();
        require(!isBlackListAddress(account), "DAO:DLG:Address in blacklist cannot vote.");
        uint64 currentTime = uint64(block.timestamp);
        require(currentTime > _candidateApplicationEnd() && currentTime < _endVotingElectionTime(),"DAO:DLG: We are not in voting period!");
        uint64 currentPeriod = getCurrentPeriod();
        (bool candidate, uint16 key) = isCandidate(currentPeriod, candidateAccount);
        require(candidate,"DAO:DLG:This wallet is not a candidate.");

        uint256[] memory _nfts = INFT(nft).holderNFTs(account);

        uint256 _votingPower;
        for (uint i = 0; i < _nfts.length; i++) {
            uint256 nftId = _nfts[i];
            // If user is not voted and is not minted his NFT's
            if(!isVotedNFT[currentPeriod][nftId] && !isBlackListNFT(nftId)){
                _votingPower += _nftVotingPower(nftId);
                isVotedNFT[currentPeriod][nftId] = true;
            }
        }

        uint256 stakeVote = _stakeVotingPower(account);
        if(stakeVote > 0 && !isVotedAddress[currentPeriod][account]){
            isVotedAddress[currentPeriod][account] = true;
            _votingPower += stakeVote; 
        }
        
        require(_votingPower > 0,"DAO:DLG:There is no available voting power.");
        usedVotingPower[currentPeriod][account] += _votingPower;
        candidatesOfElection[currentPeriod][key].voting += _votingPower;
        emit VoteCandidate(account, candidateAccount);
    }

    /**
     * @notice Election period is over and  set new 7 delegates.
     */

    function endElection () external nonReentrant {
        uint64 currentPeriod = getCurrentPeriod(); 
        uint64 currentTime = uint64(block.timestamp); 
        uint16 totalCandidates = candidateCounter[currentPeriod]; 
        require(currentTime > _endVotingElectionTime() || 
        (currentTime > _candidateApplicationEnd() && totalCandidates <= DELEGATE_COUNT), 
        "DAO:DLG:Election process is still continue.");
        uint64 lastPeriod = ((electionTime - LAUNCH_TIME) / MANAGEMENT_PERIOD) - 1;

        if (totalCandidates >= DELEGATE_COUNT) {
            // Sort candidates according to vote
            for (uint16 i = 0; i < totalCandidates; i++) {
                uint16 highestVoteIndex = i;
                for (uint16 j = i + 1; j < totalCandidates; j++) {
                    if (candidatesOfElection[currentPeriod][j].voting > candidatesOfElection[currentPeriod][highestVoteIndex].voting) {
                        highestVoteIndex = j;
                    }
                }
                Candidates memory temp = candidatesOfElection[currentPeriod][i];

                candidatesOfElection[currentPeriod][i] = candidatesOfElection[currentPeriod][highestVoteIndex];
                candidatesOfElection[currentPeriod][highestVoteIndex] = temp;
            }
 
            // set new delegates
            for (uint16 i = 0; i < totalCandidates; i++) {
                if (i < DELEGATE_COUNT) {
                    address newCandidateAddress = candidatesOfElection[currentPeriod][i].account;
                    _delegates[currentPeriod].push(newCandidateAddress);
                } 
            }
        }else{
            // If application quantity is lower than seven continue with previous delegates
            for (uint64 i = lastPeriod + 1; i <= currentPeriod; i++) {
                _setNewDelegates(_delegates[lastPeriod], i);
            }
            
        }

        electionTime = _candidateApplicationStart() + MANAGEMENT_PERIOD;

        emit ElectionEnded();
    }

    // ===========================================
    // PUBLIC FUNCTIONS
    // ===========================================
    
    /**
     * @notice When contract is deployed, 7 delegates initiliazed.
     * @param firstDelegates initiliazing first 7 delegates.
     */
    function setFirstDelegates(address[] memory firstDelegates) external onlyOwner {
        require(_delegates[0].length == 0, "DAO:DLG:Delegates already added.");
        require(firstDelegates.length == DELEGATE_COUNT, "DAO:DLG:Must initialize with 7 delegates.");

        for (uint256 i = 0; i < firstDelegates.length; i++) {
            for (uint256 j = i + 1; j < firstDelegates.length; j++) {
                require(firstDelegates[i] != firstDelegates[j], "DAO:DLG:Duplicate delegate address found.");
            }
        }
        _setNewDelegates(firstDelegates, 0);
    }

    function _setNewDelegates(address[] memory newDelegates, uint64 period) internal {
        for (uint8 i = 0; i < DELEGATE_COUNT; i++) {
            address delegate = newDelegates[i]; 
            _delegates[period].push(delegate);
        }
    }

    function getAllCandidates (uint64 period) public view returns(Candidates[] memory){
        uint16 _candidateCount = candidateCounter[period];
        Candidates[] memory allCandidates = new Candidates[](_candidateCount);

        for(uint16 i = 0; i < _candidateCount; i++) {
            allCandidates[i] = candidatesOfElection[period][i];
        }
        return allCandidates;
    }

    /**
     * @notice listed delegates by period number.
     * @param period The number of period to list delegates.
     * @return Returning All delegates given by period.
    */
    function getAllDelegates (uint64 period) public view returns(address[] memory){
        uint64 currentPeriod = getCurrentPeriod();
        require(period <= currentPeriod,"DAO:DLG:Wrong period entered!");
        address[] memory delegates = new address[](DELEGATE_COUNT);
        for (uint i = 0; i < DELEGATE_COUNT; i++) {
            delegates[i] = _delegates[period][i];
        }
        return delegates;
    }

    /**
     * @notice Checks if we are in election period.
     */
    function isElectionPeriod() public view returns(bool){
        uint64 currentTime = uint64(block.timestamp); 
        return currentTime >= _candidateApplicationStart() && currentTime <= _endVotingElectionTime() ? true : false;
        
    }

    /**
     * 
     * @param period The election period for candidates.
     * @param account Address of the candidate.
     * @return A boolean indicate candidate application status.
     * @return A boolean indicate candidate application order.
     */
    function isCandidate (uint64 period, address account) public view returns(bool, uint16){
        for (uint16 i = 0; i < candidateCounter[period]; i++) {
            if(candidatesOfElection[period][i].account == account){
                return (true, i);
            }
        }
        return (false, 0);
    }
    

    // ===========================================
    // PRIVATE FUNCTIONS
    // ===========================================

    /**
     * @dev Candidate Application Start time.
     */
    function _candidateApplicationStart() private view returns(uint64){
        return LAUNCH_TIME + (MANAGEMENT_PERIOD * getCurrentPeriod());
    }

    /**
     * @dev Candidate Application End time.
     */
    function _candidateApplicationEnd() private view returns(uint64){
        return _candidateApplicationStart() + CANDIDATE_APPLY_TIME; 
    }

    /**
     * @dev End voting Election Time.
     */
    function _endVotingElectionTime() private view returns(uint64){
        return _candidateApplicationEnd() + CANDIDATE_VOTING_TIME;
    }
}

/**
 * @title DAOProposals 
 * @dev Contract handling proposals within the DAO system. 
 */
abstract contract DAOProposals is DAODelegates{
    // Fund Events
    event CreateFund(
        uint256 vipId,
        uint8 categoryId,
        address to,
        uint256 amount
    );

    event Voted(uint256 vipId, address delegate);
    event FundSucces(
        uint256 vipId,
        uint8 categoryId,
        address to,
        uint256 amount
    );

    // Proposals
    struct FundList {
        uint256 id;
        uint256 vipId;
        uint8 categoryId;
        address account;
        uint256 amount;
        uint64 startTime;
        address[] votes;
        bool isCompleted;
    }


    struct VotedProposalList{
        uint256 vipId;
        uint64 startTime;
        uint256 yes;
        uint256 no;
        uint256 abstain;
        address[] votes;
        bool isCompleted;
    }
    uint256 public lastVipId;
    uint256 public fundId;

    mapping (uint256 => VotedProposalList) internal _proposalVoting;
    mapping(uint256 => FundList) internal _funds;


    function setProposalResults(uint256 vipId, uint256 yesVotingPower, uint256 noVotingPower, uint256 abstainVotingPower) external onlyDelegate nonReentrant {
        
        VotedProposalList storage vote = _proposalVoting[vipId]; 

        require(vote.votes.length == 0, "DAO:VOTE:vipId already used!");

        vote.vipId = vipId;
        vote.startTime = uint64(block.timestamp);
        vote.yes = yesVotingPower;
        vote.no = noVotingPower;
        vote.abstain = abstainVotingPower;
        vote.votes.push(_msgSender()); 

        if(lastVipId < vipId){
            lastVipId = vipId;
        }
    }

    function voteProposalResults(uint256 vipId) external onlyDelegate nonReentrant {
        uint64 currentTime = uint64(block.timestamp);
        VotedProposalList storage vote = _proposalVoting[vipId];  

        require(!vote.isCompleted, "DAO:VOTE:This vipId is completed!");
        require(
            currentTime <= vote.startTime + PROPOSAL_VOTING_TIME,
            "DAO:VOTE:Fund selection expired."
        );
        address delegate = _msgSender();
        require(!isVoted(_proposalVoting[vipId].votes, delegate), "DAO:VOTE:Already voted."); 

        vote.votes.push(delegate);
        if (_proposalVoting[vipId].votes.length == SUCCESS_COUNT) {
            vote.isCompleted = true; 
        }
    }

    /**
     * @notice Creates a new proposal.
     * @param vipId Identifier for the proposal.
     * @param categoryId Category ID for the proposal.
     * @param account Address to which the tokens will be transferred.
     * @param amount Amount of tokens to transfer.
     */
    function createFundTransfer(
        uint256 vipId,
        uint8 categoryId,
        address account,
        uint256 amount
    ) external onlyDelegate nonReentrant {
        VotedProposalList memory prVoting = _proposalVoting[vipId];
        require(prVoting.isCompleted && prVoting.yes > prVoting.no && prVoting.yes > prVoting.abstain, "DAO:PRP:vipId is unconfirmed!");
        require(!isBlackListAddress(account), "DAO:PRP:Account is blacklisted.");

        uint256 freeAmount = getCategoryUnlockAmount(categoryId);
        require(
            freeAmount >= amount,
            "DAO:PRP:There are not enough unlock tokens"
        );
        FundList storage fund = _funds[fundId]; 
        fund.id = fundId;
        fund.vipId = vipId;
        fund.categoryId = categoryId;
        fund.account = account;
        fund.amount = amount;
        fund.startTime = uint64(block.timestamp);
        fund.votes.push(_msgSender());
        
        fundId++;

        emit CreateFund(
            vipId,
            categoryId,
            account,
            amount
        );
    }

    /**
     * @notice Votes for a proposal. 
     * @param id ID of the proposal to vote for.
     */
    function voteFundTransfer(uint256 id) external onlyDelegate nonReentrant {
        uint64 currentTime = uint64(block.timestamp);
        FundList storage fund = _funds[id]; 

        require(
            currentTime <= fund.startTime + PROPOSAL_VOTING_TIME,
            "DAO:PRP:Fund selection expired" 
        );
        require(!fund.isCompleted, "DAO:PRP:This proposal is completed");

        address delegate = _msgSender();

        require(!isVoted(fund.votes, delegate), "DAO:PRP:Already voted");

        fund.votes.push(delegate);

        if (fund.votes.length >= SUCCESS_COUNT) {
            fund.isCompleted = true; 

            _categories[fund.categoryId].used += fund.amount;
            SafeERC20.safeTransfer(IERC20(token), fund.account, fund.amount);
            emit FundSucces(
                fund.vipId,
                fund.categoryId,
                fund.account,
                fund.amount
            );
        }
    }

    /**
     * @notice Retrieves proposals within a specified range.
     * @param startId Start ID of the proposals.
     * @param endId End ID of the proposals.
     * @return An array of proposals within the specified range.
     */
    function getFundTransferInRange(
        uint256 startId,
        uint256 endId
    ) external view returns (FundList[] memory) {
        require(endId > startId, "DAO:Invalid range");

        if (startId > fundId) startId = fundId;
        if (endId > fundId) endId = fundId;

        FundList[] memory results = new FundList[](endId - startId);
        uint256 count = 0;
        for (uint256 i = startId; i < endId; i++) {
            results[count] = _funds[i];
            count++;
        }
        return results;
    }

    function getFundTransferId(
        uint256 id
    ) public view returns (FundList memory) {
        return _funds[id];
    }

    function getProposalInRange(
        uint256 startVipId,
        uint256 endVipId
    ) external view returns (VotedProposalList[] memory) {
        require(endVipId > startVipId, "DAO:Invalid range");

        if (startVipId > lastVipId) startVipId = lastVipId;
        if (endVipId > lastVipId) endVipId = lastVipId + 1;

        VotedProposalList[] memory results = new VotedProposalList[](endVipId - startVipId);
        uint256 count = 0; 
        for (uint256 i = startVipId; i < endVipId; i++) {
            results[count] = _proposalVoting[i]; 
            count++;
        }
        return results;
    }
    
    /**
     * @notice Retrieves a proposal by its VIP ID.
     * @param viplId VIP ID of the proposal.
     * @return The proposal corresponding to the given VIP ID.
     */
    function getProposalVipId(
        uint256 viplId
    ) public view returns (VotedProposalList memory) {
        return _proposalVoting[viplId]; 
    }
}


/**
 * @title VDAO
 * @dev Contract representing a Decentralized Autonomous Organization (DAO) with mechanisms and proposals.
 */
contract VDAO is DAOProposals {
    event SetAddresses(address token, address nft, address stake);
    /**
     * @dev Constructor to initialize VDAO contract.
     * @param initialOwner Address of the initial owner.
     * @param launchTime Timestamp of the DAO launch.
     * @param electionPeriod Duration of the election period.
     * @param candTime Duration of the candidate nomination period.
     * @param candVotingTime Duration of the voting period.
     * @param proposalVotingTime Duration of the voting period. 
     */
    constructor(
        address initialOwner,
        uint64 launchTime,
        uint64 electionPeriod,
        uint64 candTime,
        uint64 candVotingTime,
        uint64 proposalVotingTime
    )
        DAOMechanisim(
            initialOwner,
            launchTime,
            electionPeriod,
            candTime,
            candVotingTime,
            proposalVotingTime
        )
    {}

    /**
     * @dev Sets the addresses of related contracts.
     * @param tokenAddress Address of the token contract.
     * @param nftAddress Address of the NFT contract.
     * @param stakeAddress Address of the stake contract.
     */
    function setAddresses(
        address tokenAddress,
        address nftAddress,
        address stakeAddress
    ) external onlyOwner {
        require(
            tokenAddress != address(0),
            "DAO:Token address can not be zero."
        );
        require(
            nftAddress != address(0),
            "DAO:NFT address can not be zero."
        );
        require(
            stakeAddress != address(0),
            "DAO:Stake address can not be zero."
        );
        token = tokenAddress;
        nft = nftAddress;
        stake = stakeAddress;

        emit SetAddresses(token, nft, stake);
    }
}
