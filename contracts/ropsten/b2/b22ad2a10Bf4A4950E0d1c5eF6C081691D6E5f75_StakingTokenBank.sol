pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./models/staking/StakeData.sol";

contract StakingTokenBank is Ownable, ReentrancyGuard{
    using SafeMath for uint;

    //Token that can be staked(GIVE)
    IERC20 public StakingToken;
    //mapping containing stake data for address
    mapping(address => StakeData) public StakeDatas;

    //total staked tokens over all pools
    uint256 public TotalStakedTokens;
    // total staked tokens per pool based on stakingPoolId
    mapping(string => uint256) public TotalStakedPoolTokens;

    //Emitted when a stake was successful
    event Staked(address staker, string stakingPoolId, uint256 amount, uint256 entryId);
    //Emitted when a unstake was successful
    event Unstaked(address staker, string stakingPoolId, uint256 amount, uint256 entryId);

    constructor(address stakingToken){
        StakingToken = IERC20(stakingToken);
    }

    /**
     * @dev Stake the given amount in the given staking pool
     * @param stakingPoolId the id of the staking pool
     * @param amount the amount to be staked
     * @param charities percentage setting for charity distribution
    */
    function Stake(string memory stakingPoolId, uint256 amount, StakingPoolEntryCharity[] memory charities) nonReentrant external{
        RequireCharityCheck(charities);
        require(amount > 0, "Cannot stake 0");
        require(StakingToken.allowance(_msgSender(), address(this)) >= amount , "Allowance not set");
        //update all totals
        StakeDatas[_msgSender()].TotalStaked += amount;
        StakeDatas[_msgSender()].StakingPoolDatas[stakingPoolId].TotalStaked += amount;
        TotalStakedPoolTokens[stakingPoolId] += amount;
        TotalStakedTokens += amount;
        //create entry
        uint256 entryId =  StakeDatas[_msgSender()].StakingPoolDatas[stakingPoolId].EntriesIndexer.length.add(1);
        StakeDatas[_msgSender()].StakingPoolDatas[stakingPoolId].EntriesIndexer.push(entryId);
        StakeDatas[_msgSender()].StakingPoolDatas[stakingPoolId].Entries[entryId].EntryDate = block.timestamp;
        StakeDatas[_msgSender()].StakingPoolDatas[stakingPoolId].Entries[entryId].Amount += amount;
        for(uint i=0; i<charities.length; i++)
        {
            StakingPoolEntryCharity memory entryCharity = charities[i];
            StakeDatas[_msgSender()].StakingPoolDatas[stakingPoolId].Entries[entryId].StakingPoolEntryCharities.push(entryCharity);
        }
        StakingToken.transferFrom(_msgSender(), address(this), amount);
        emit Staked(_msgSender(), stakingPoolId, amount, entryId);
    }

    /**
     * @dev Unstake the given amount in the given staking pool
     * @param stakingPoolId the id of the staking pool
     * @param entryId the id of the entry to unstake
    */
    function UnStake(string memory stakingPoolId, uint256 entryId) nonReentrant external{
        require(StakeDatas[_msgSender()].StakingPoolDatas[stakingPoolId].Entries[entryId].EntryDate != 0, "Staking entry does not exist");
        require(StakeDatas[_msgSender()].StakingPoolDatas[stakingPoolId].Entries[entryId].ExitDate == 0, "Already unstaked");
        uint256 amount = StakeDatas[_msgSender()].StakingPoolDatas[stakingPoolId].Entries[entryId].Amount;
        StakeDatas[_msgSender()].StakingPoolDatas[stakingPoolId].Entries[entryId].ExitDate = block.timestamp;
        StakeDatas[_msgSender()].TotalStaked -= amount;
        StakeDatas[_msgSender()].StakingPoolDatas[stakingPoolId].TotalStaked -= amount;
        TotalStakedPoolTokens[stakingPoolId] -= amount;
        TotalStakedTokens -= amount;
        StakingToken.transfer(_msgSender(), amount);
        emit Unstaked(_msgSender(), stakingPoolId, amount, entryId);
    }

    /**
     * @dev Return total amount of tokens staked for address
     * @param staker the address of the staker
    */
    function GetTotalStakedForAddress(address staker) public view returns(uint256){
        return StakeDatas[staker].TotalStaked;
    }

    /**
     * @dev Returns the total amount of tokens staked for the given address in the given pool
     * @param staker the address of the staker
     * @param stakingPoolId the id of the staking pool
    */
    function GetTotalStakedInPoolForAddress(address staker, string memory stakingPoolId) public view returns(uint256){
        return StakeDatas[staker].StakingPoolDatas[stakingPoolId].TotalStaked;
    }

    /**
     * @dev returns the stakingpool entries indexer for a given staking pool (this is a list of id's for staking entries in the pool)
     * @param staker the address of the staker
     * @param stakingPoolId the id of the staking pool
     */
    function GetStakingPoolEntriesIndexer(address staker, string memory stakingPoolId) public view returns(uint256[] memory){
        uint256[] memory result = new uint256[](StakeDatas[staker].StakingPoolDatas[stakingPoolId].EntriesIndexer.length);
        for(uint i=0; i< StakeDatas[staker].StakingPoolDatas[stakingPoolId].EntriesIndexer.length; i++)
        {
            uint256 entryIndex = StakeDatas[staker].StakingPoolDatas[stakingPoolId].EntriesIndexer[i];
            result[i] = entryIndex;
        }
        return result;
    }

    /**
     * @dev returns the stakingpool entry for given entry id
     * @param staker the address of the staker
     * @param stakingPoolId the id of the staking pool
     * @param entryId the id of the staking pool entry
     */
    function GetStakingPoolEntry(address staker, string memory stakingPoolId, uint256 entryId) public view returns(StakingPoolEntry memory){
        return StakeDatas[staker].StakingPoolDatas[stakingPoolId].Entries[entryId];
    }

    /**
     * @dev returns the charity settings for given entry id
     * @param staker the address of the staker
     * @param stakingPoolId the id of the staking pool
     * @param entryId the id of the staking pool entry
     */
    function GetStakingPoolEntryCharities(address staker, string memory stakingPoolId, uint256 entryId)public view returns(StakingPoolEntryCharity[] memory){
        StakingPoolEntryCharity[] memory result = new StakingPoolEntryCharity[](StakeDatas[staker].StakingPoolDatas[stakingPoolId].Entries[entryId].StakingPoolEntryCharities.length);
        for(uint i=0; i< StakeDatas[staker].StakingPoolDatas[stakingPoolId].Entries[entryId].StakingPoolEntryCharities.length; i++)
        {
            StakingPoolEntryCharity storage charity = StakeDatas[staker].StakingPoolDatas[stakingPoolId].Entries[entryId].StakingPoolEntryCharities[i];
            result[i] = charity;
        }
        return result;
    }

    /**
     * @dev check to see if given charity percentages add up to 100%
     * @param charities give charities
     */
    function RequireCharityCheck(StakingPoolEntryCharity[] memory charities) private{
        uint256 percentage = 0;
        for(uint i=0; i< charities.length; i++)
        {
            percentage += charities[i].Percentage;
        }
        require(percentage == 100, "Charity percentages do not total 100");
    }
}