/**
 *Submitted for verification at Etherscan.io on 2021-12-21
*/

// SPDX-License-Identifier: No-License
pragma solidity ^0.8;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract Staker is Ownable {       

    //Vars
    uint256 public poolBalance;
    uint256 public totalStaked;
    uint256 public totalStakedNextPool;
    uint256 depositEthForRewardsTime;
    
    mapping(address => uint256) public userStakeTime;
    mapping(address => uint256) public userStakeAmount;

    event Deposit(address _user, uint256 _amount);
    event Stake(address _user, uint256 _amount);
    event Withdraw(address _user, uint256 _amount);      

    constructor(){
        poolBalance = 0;
        totalStaked = 0;
        totalStakedNextPool = 0;
        depositEthForRewardsTime = block.timestamp + 604800;
    }   
            
    //Team
    function depositEthForRewards() payable external onlyOwner{
        require(msg.value > 0, "You cannot deposit 0 Eth.");                        
        poolBalance += msg.value;          
        totalStaked += totalStakedNextPool;
        totalStakedNextPool = 0;
        depositEthForRewardsTime = block.timestamp;  
        
        emit Deposit(msg.sender, msg.value);     
    }

    //User
    function stake() payable external{
        require(msg.value > 0, "You cannot stake 0 Eth.");             
        userStakeAmount[msg.sender] = msg.value;    

        if(block.timestamp > depositEthForRewardsTime){
            totalStakedNextPool += msg.value;
        }else{
            totalStaked += msg.value;
        }

        userStakeTime[msg.sender] = block.timestamp;                

        emit Stake(msg.sender, msg.value);
    }


    function withdraw() external{                
        require(userStakeAmount[msg.sender] > 0, "Your staked balance is 0 Eth.");   
        require(userStakeTime[msg.sender] < depositEthForRewardsTime, "You must wait for the next week.");
        uint256 staked = userStakeAmount[msg.sender];        
        uint256 reward = staked * (poolBalance / totalStaked);        
        userStakeAmount[msg.sender] = 0; 
        totalStaked -= staked;
        poolBalance -= reward;

        payable(msg.sender).transfer(staked + reward);

        emit Withdraw(msg.sender, staked + reward);        
    }

    //Public
    function actualRewardPerEth() public view returns(uint256){
        return 1 * (poolBalance / totalStaked);
    }
}