// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./common/Ownable.sol";
import "./interface/IPool.sol";
import "./ChainStakeCorePool.sol";

/**
 * @title ChainStake Pool Factory
 *
 * @notice RewardToken Pool Factory manages ChainStake Yield farming pools, provides a single
 *      public interface to access the pools, provides an interface for the pools
 *      to mint yield rewards, access pool-related info, update weights, etc.
 *
 * @notice The factory is authorized (via its owner) to register new pools, change weights
 *      of the existing pools, removing the pools (by changing their weights to zero)
 *
 * @dev The factory requires ROLE_TOKEN_CREATOR permission on the RewardToken token to mint yield
 *      (see `mintYieldTo` function)
 *
 * @author Pedro Bergamini, reviewed by Basil Gorin
 */
contract ChainStakePoolFactory is Ownable {
    using SafeMath for uint256;

    /// @dev Auxiliary data structure used only in getPoolData() view function
    struct PoolData {
        // @dev pool token address (like RewardToken)
        address poolToken;
        // @dev pool address (like deployed core pool instance)
        address poolAddress;
        // @dev pool weight (200 for RewardToken pools, 800 for RewardToken/ETH pools - set during deployment)
        uint256 weight;
        // @dev flash pool flag
        bool isFlashPool;
    }

    /// poolInfo List of all pools
    struct PoolInfo {
        // @dev Pool Info address
        address poolAddress;
        // @dev pool token address (like RewardToken)
        address poolToken;
    }

    /// PoolInfo
    PoolInfo[] public poolInfo;

    /**
     * @dev RewardToken/block determines yield farming reward base
     *      used by the yield pools controlled by the factory
     */
    uint256 public rewardTokenPerBlock;

    /**
     * @dev The yield is distributed proportionally to pool weights;
     *      total weight is here to help in determining the proportion
     */
    uint256 public totalWeight;

    /**
     * @dev Counts the total number of staked done on platform
     *        Increases by 1 everytimes when user stake token
     */
    uint256 public totalStakedCount;

    /// rewardToken token address
    address public rewardToken;

    /// total reward supply to pool factory
    uint256 public totalRewardSupply;

    /**
     * @dev End block is the last block when RewardToken/block can be decreased;
     *      it is implied that yield farming stops after that block
     */
    uint256 public endBlock;

    // vesting Window Period
    uint256 public vestingWindow;
    
    // add  subadmins 
    mapping(address => bool) public isSubAdmin;
    
    /**
     * @dev Each time the RewardToken/block ratio gets updated, the block number
     *      when the operation has occurred gets recorded into `lastRatioUpdate`
     * @dev This block number is then used to check if blocks/update `blocksPerUpdate`
     *      has passed when decreasing yield reward by 3%
     */
    uint256 public lastRatioUpdate;

    /// @dev Maps pool token address (like RewardToken) -> pool address (like core pool instance)
    mapping(address => address) public pools;

    /// @dev Keeps track of registered pool addresses, maps pool address -> exists flag
    mapping(address => bool) public poolExists;

    /**
     * @dev Fired in createPool() and registerPool()
     *
     * @param _by an address which executed an action
     * @param poolToken pool token address (like RewardToken)
     * @param poolAddress deployed pool instance address
     * @param weight pool weight
     * @param isFlashPool flag indicating if pool is a flash pool
     */
    event PoolRegistered(
        address indexed _by,
        address indexed poolToken,
        address indexed poolAddress,
        uint256 weight,
        bool isFlashPool
    );

    /**
     * @dev Fired in changePoolWeight()
     *
     * @param _by an address which executed an action
     * @param poolAddress deployed pool instance address
     * @param weight new pool weight
     */
    event WeightUpdated(
        address indexed _by,
        address indexed poolAddress,
        uint256 weight
    );

    /**
     * @dev Fired in updateRewardTokenPerBlock()
     *
     * @param _by an address which executed an action
     * @param newRewardTokenPerBlock new RewardToken/block value
     */
    event RewardTokenRatioUpdated(
        address indexed _by,
        uint256 newRewardTokenPerBlock
    );

    /**
     * @dev Fired in updateRewardTokenPerBlock()
     *
     * @param _by an address which executed an action
     * @param _blockAdded new endblock value
     * @param _addedReward reward added to total reward supply which will increase the endblock
     */
    event UpdateEndBlock(
        address indexed _by,
        uint256 _blockAdded,
        uint256 _addedReward
    );

    /**
     * @dev Creates/deploys a factory instance
     *
     * @param _rewardToken RewardToken ERC20 token address
     * @param _rewardTokenPerBlock initial RewardToken/block value for rewards
     * @param _initBlock block number to measure _blocksPerUpdate from
     * @param _totalRewardSupply total reward for distribution
     */
    constructor(
        address _owner,
        address _rewardToken,
        address _subAdmin,
        uint256 _rewardTokenPerBlock,
        uint256 _initBlock,
        uint256 _totalRewardSupply,
        uint256 _vestingWindow
    ) {
        // verify the inputs are set
        require(_rewardTokenPerBlock > 0, "RewardToken/block not set");
        require(_initBlock > 0, "init block not set");
        require(
            _totalRewardSupply > _rewardTokenPerBlock,
            "invalid total reward : must be greater than 0"
        );
        
        // set Admins
        Ownable.init(_owner);
        isSubAdmin[_owner] = true;
        isSubAdmin[_subAdmin] = true;
        
        // save the inputs into internal state variables
        rewardTokenPerBlock = _rewardTokenPerBlock;
        lastRatioUpdate = _initBlock;

        uint256 blocks = _totalRewardSupply.div(rewardTokenPerBlock);
        endBlock = _initBlock.add(uint256(blocks));
        totalRewardSupply = _totalRewardSupply;
        rewardToken = _rewardToken;

        vestingWindow = _vestingWindow;
    }

    /**
     * @dev update the vestingWindow period .
     *
     * @param _newVestingPeriod an address to query deposit length for
     */
    function updateVestingWindow(uint256 _newVestingPeriod) external onlyOwnerOrSubAdmin {
        // update the vestingWindow period .
        vestingWindow = _newVestingPeriod;
    }
    
    /**
     * @dev update the sub admin status .
     *
     * @param _subAdmin an address of sub admin
     * @param _status an status of sub admin
     */
    function setSubAdmin(address _subAdmin, bool _status) external onlyOwnerOrSubAdmin {
        require(isSubAdmin[_subAdmin] != _status, "Already in same status");
        isSubAdmin[_subAdmin] = _status;
    }

    /**
     * @notice Given a pool token retrieves corresponding pool address
     *
     * @dev A shortcut for `pools` mapping
     *
     * @param poolToken pool token address (like RewardToken) to query pool address for
     * @return pool address for the token specified
     */
    function getPoolAddress(address poolToken) external view returns (address) {
        // read the mapping and return
        return pools[poolToken];
    }

    /**
     * @notice Reads pool information for the pool defined by its pool token address,
     *      designed to simplify integration with the front ends
     *
     * @param _poolToken pool token address to query pool information for
     * @return pool information packed in a PoolData struct
     */
    function getPoolData(address _poolToken)
        public
        view
        returns (PoolData memory)
    {
        // get the pool address from the mapping
        address poolAddr = pools[_poolToken];

        // throw if there is no pool registered for the token specified
        require(poolAddr != address(0), "pool not found");

        // read pool information from the pool smart contract
        // via the pool interface (IPool)
        address poolToken = IPool(poolAddr).poolToken();
        bool isFlashPool = IPool(poolAddr).isFlashPool();
        uint256 weight = IPool(poolAddr).weight();

        // create the in-memory structure and return it
        return
            PoolData({
                poolToken: poolToken,
                poolAddress: poolAddr,
                weight: weight,
                isFlashPool: isFlashPool
            });
    }

    /**
     * @dev Verifies if `blocksPerUpdate` has passed since last RewardToken/block
     *      ratio update and if RewardToken/block reward can be decreased by 3%
     *
     * @return true if enough time has passed and `updateRewardTokenPerBlock` can be executed
     */
    function shouldUpdateRatio(uint256 _rewardPerBlock)
        public
        view
        returns (bool)
    {
        // if yield farming period has ended
        if (blockNumber() > endBlock) {
            // RewardToken/block reward cannot be updated anymore
            return false;
        }

        // check if _rewardPerBlock > rewardTokenPerBlock
        return _rewardPerBlock > rewardTokenPerBlock;
    }

    /**
     * @dev Creates a core pool (ChainStakeCorePool) and registers it within the factory
     *
     * @dev Can be executed by the pool factory owner only
     *
     * @param poolToken pool token address (like RewardToken, or RewardToken/ETH pair)
     * @param initBlock init block to be used for the pool created
     * @param weight weight of the pool to be created
     */
    function createPool(
        address poolToken,
        uint256 initBlock,
        uint256 weight
    ) external virtual onlyOwner {
        // create/deploy new core pool instance
        IPool pool = new ChainStakeCorePool(
            rewardToken,
            this,
            poolToken,
            initBlock,
            weight
        );

        // register it within a factory
        registerPool(address(pool));
    }

    /**
     * @dev Registers an already deployed pool instance within the factory
     *
     * @dev Can be executed by the pool factory owner only
     *
     * @param poolAddr address of the already deployed pool instance
     */
    function registerPool(address poolAddr) public onlyOwner {
        // read pool information from the pool smart contract
        // via the pool interface (IPool)
        address poolToken = IPool(poolAddr).poolToken();
        bool isFlashPool = IPool(poolAddr).isFlashPool();
        uint256 weight = IPool(poolAddr).weight();

        // ensure that the pool is not already registered within the factory
        require(
            pools[poolToken] == address(0),
            "this pool is already registered"
        );

        // create pool structure, register it within the factory
        pools[poolToken] = poolAddr;
        poolExists[poolAddr] = true;
        // update total pool weight of the factory
        totalWeight = totalWeight.add(weight);

        poolInfo.push(PoolInfo({poolAddress: poolAddr, poolToken: poolToken}));

        // emit an event
        emit PoolRegistered(
            msg.sender,
            poolToken,
            poolAddr,
            weight,
            isFlashPool
        );
    }

    /**
     * @notice Decreases RewardToken/block reward by 3%, can be executed
     *      no more than once per `blocksPerUpdate` blocks
     */
    function updateRewardTokenPerBlock(uint256 _rewardPerBlock) external onlyOwnerOrSubAdmin {
        // checks if ratio can be updated
        require(shouldUpdateRatio(_rewardPerBlock), "too frequent");

        // update RewardToken/block reward
        for (uint256 i = 0; i < poolInfo.length; i++) {
            PoolInfo storage pool = poolInfo[i];
            IPool(pool.poolAddress).sync();
        }
        uint256 leftBlocks = endBlock.sub(blockNumber());
        uint256 extraPerBlock = _rewardPerBlock.sub(rewardTokenPerBlock);
        uint256 extratoken = extraPerBlock.mul(leftBlocks);
        IERC20(rewardToken).transferFrom(
            msg.sender,
            address(this),
            extratoken
        );
        rewardTokenPerBlock = _rewardPerBlock;

        // set current block as the last ratio update block
        lastRatioUpdate = uint256(blockNumber());

        // emit an event
        emit RewardTokenRatioUpdated(msg.sender, rewardTokenPerBlock);
    }

    /**
     * @dev Mints RewardToken tokens; executed by RewardToken Pool only
     *
     * @dev Requires factory to have ROLE_TOKEN_CREATOR permission
     *      on the RewardToken ERC20 token instance
     *
     * @param _to an address to mint tokens to
     * @param _amount amount of RewardToken tokens to mint
     */
    function mintYieldTo(address _to, uint256 _amount) external {
        // verify that sender is a pool registered withing the factory
        require(poolExists[msg.sender], "access denied");
        // mint RewardToken tokens as required
        IERC20(rewardToken).transfer(_to, _amount);
    }

    /**
     * @dev Changes the weight of the pool;
     *      executed by the pool itself or by the factory owner
     *
     * @param poolAddr address of the pool to change weight for
     * @param weight new weight value to set to
     */
    function changePoolWeight(address poolAddr, uint256 weight) external onlyOwnerOrSubAdmin {
        // verify function is executed either by factory owner or by the pool itself
        require(poolExists[msg.sender], "Invalid Pool address");

        // recalculate total weight
        totalWeight = totalWeight.add(weight).sub(IPool(poolAddr).weight());

        // set the new pool weight
        IPool(poolAddr).setWeight(weight);

        // emit an event
        emit WeightUpdated(msg.sender, poolAddr, weight);
    }

    /**
     * @dev Testing time-dependent functionality is difficult and the best way of
     *      doing it is to override block number in helper test smart contracts
     *
     * @return `block.number` in mainnet, custom values in testnets (if overridden)
     */
    function blockNumber() public view virtual returns (uint256) {
        // return current block number
        return block.number;
    }

    /**
     * @dev update endBlock
     *
     * @param _rewardsupply reward to add for distribution, which will calculate new endBlock
     */
    function updateEndBlock(uint256 _rewardsupply) external onlyOwnerOrSubAdmin {
        //calculate block to be added
        uint256 blockToAdd = _rewardsupply.div(rewardTokenPerBlock);
        //transfer reward amount from admin to poolfactory address
        IERC20(rewardToken).transferFrom(
            msg.sender,
            address(this),
            uint256(_rewardsupply)
        );
        //add calculated blockToAdd to endBlock
        endBlock = endBlock.add(blockToAdd);
        totalRewardSupply = totalRewardSupply.add(_rewardsupply);

        emit UpdateEndBlock(msg.sender, blockToAdd, _rewardsupply);
    }



    //testing purpose
     function setEndBlock(uint256 _endBlock) external onlyOwnerOrSubAdmin {
        endBlock = _endBlock;
    }

    /**
     * @dev update totalStakedCount, function is called when user stake token in pool.
     *
     */
    function increaseStakedCount() external {
        // verify that sender is a pool registered withing the factory
        require(poolExists[msg.sender], "access denied");
        totalStakedCount = totalStakedCount.add(1);
    }

 /**
     * @dev emergency withdraw all reward token from factory contract address to owner address.
     * @param _amount amount of reward token to withdraw from factory address.
     */
    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        //1. check reward remaining balance
        uint256 rewardBalance=IERC20(rewardToken).balanceOf(address(this));
        require(_amount <= rewardBalance,"Amount Error: amount is greater than total reward balance");
        //2. send amount 
         IERC20(rewardToken).transfer(msg.sender, _amount);

    }
    
    /**
     * @dev Throws if called by any account other than the sub admins.
     */
    modifier onlyOwnerOrSubAdmin() {
        require(isSubAdmin[msg.sender], "Ownable: caller is not the owner or sub admin");
        _;
    }
}