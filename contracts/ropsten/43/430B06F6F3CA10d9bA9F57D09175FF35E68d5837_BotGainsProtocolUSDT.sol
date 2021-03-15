// SPDX-License-Identifier: MIT

pragma solidity ^0.5.0;

import "./BotGainsProtocolStorageUSDT.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BotGainsProtocolUSDT is Ownable,ReentrancyGuard {
    using SafeMath for uint256;
    
    BotGainsProtocolStorageUSDT private _protocol_storage;
    
    //state variables
    bool public locked = false;
    
    uint256 public currentCycle;
    
    bool public loss;
    
    uint256 private fragsPerUSDT;
    uint256 public timeLocked;
    uint256 public timeUnlocked;

    IERC20 public USDT;
    
    //cycle mappings
    mapping(uint256 => mapping(address => bool)) public userExistOnCycle;
    mapping(uint256 => uint256) private TOTAL_FRAGS_ON_CYCLE; //tracks total frags on a given cycle
    mapping(uint256 => uint256) private FRAGS_PER_USDT_ON_CYCLE;
    mapping(uint256 => mapping(address => uint256)) private USER_FRAGS_ON_CYCLE; //tracks capital on a given cycle\
    mapping(uint256 => uint256) public USERS_ON_CYCLE;
    mapping(uint256 => uint256) public POOL_ON_CYCLE; 

    modifier cycleHappend(){
        require(currentCycle > 0, "no cycles have occured yet");
        _;
    }
    modifier isUnlocked() {
        require(!locked, "The bot is current trading!");
        _;
    }
    modifier isNotUnlocked() {
        require(locked, "The bot is currently trading!");
        _;
    }
    modifier onlyBot() {
        require(msg.sender == _protocol_storage._tradingWallet(), "Not the trader!");
        _;
    }
    modifier onlyBonus() {
        require(msg.sender == _protocol_storage._bonusWallet(), "Not the Bonus Wallet");
        _;
    }
    
    event BotWithdraw(uint256 poolAmount, uint256 users, uint256 atTime, uint256 onCycle);
    event BotDeposit(uint256 depositAmount, uint256 forCycle, bool loss, uint256 atTime);
    event UserDeposit(uint256 depositAmount, uint256 onCycle, uint256 atTime);
    event UserWithdraw(uint256 poolAmount, uint256 onCycle, uint256 atTime);

    constructor (address _storage, address _usdt) public {
        _protocol_storage = BotGainsProtocolStorageUSDT(_storage);
        
        //assign state variables
        USDT = IERC20(_usdt);
        currentCycle = 0;
        fragsPerUSDT = 1e30;
        FRAGS_PER_USDT_ON_CYCLE[0] = fragsPerUSDT;
        timeUnlocked = now;
        timeLocked=0;
        USERS_ON_CYCLE[currentCycle] = 0;
    }
    
    //revert payable fallback
    function() payable external {
        revert("Use userDeposit");
    }
    
    /******************************************
    ************* USER FUNCTIONS **************
    *******************************************/

    //userDeposit:
    function userDeposit(uint256 usdtAmount) external payable isUnlocked nonReentrant {
    
        require(_protocol_storage._minUSDT() <= usdtAmount, "Minimum not met"); //good
        incrementUser(_msgSender()); //good
                
        require(USDT.transferFrom(_msgSender(), address(this), usdtAmount));
        
        uint256 userUSDTamount = usdtAmount.mul(97750).div(1e5); //97.75%
        uint256 userFeeAmount = usdtAmount.mul(2000).div(1e5); //2%
        uint256 userDivFeeAmount = usdtAmount.mul(250).div(1e5); //.25%
        
        //check user deposit into current pool & check that this deposit does not exceed pool limit
        checkUserLimit(_msgSender(), userUSDTamount);
        
        //update this user's balance for this investment cycle
        uint256 fragAmount = (userUSDTamount).mul(FRAGS_PER_USDT_ON_CYCLE[currentCycle]); //user frag balance -- good

        //if multiple deposits have been made this step makes sure frags have been updates correctly with additional deposit
        USER_FRAGS_ON_CYCLE[currentCycle][_msgSender()] = USER_FRAGS_ON_CYCLE[currentCycle][_msgSender()].add(fragAmount);

        //keep track of total frags on this cycle
        TOTAL_FRAGS_ON_CYCLE[currentCycle] = TOTAL_FRAGS_ON_CYCLE[currentCycle].add(fragAmount); // good -- track totals

        //add liquidity to pool for this round of investment
        POOL_ON_CYCLE[currentCycle] = POOL_ON_CYCLE[currentCycle].add(userUSDTamount); //good -- updates total USDT alongside FRAGS

        userExistOnCycle[currentCycle][_msgSender()] = true;

        //transfer fees
        transferToAdmin(userFeeAmount); // good
        transferToDivs(userDivFeeAmount); // good

        emit UserDeposit(userUSDTamount, currentCycle, block.timestamp);
    }

    
    //userWithdraw:
    function userWithdrawFundsOnCycle(uint256 _cycle) external nonReentrant isUnlocked{
        
        //get user frags on this cycle
        uint256 fragAmount = USER_FRAGS_ON_CYCLE[_cycle][_msgSender()]; // good

        if(USER_FRAGS_ON_CYCLE[_cycle][_msgSender()] == 0) {
            revert("BotGains: Nothing to Withdraw");
        }
        
        //convert these frags to USDT amount 
        uint256 USDTamount = calculateUSDT(fragAmount, _cycle); // good
        
        //send to user
        USDT.transfer(_msgSender(), USDTamount);

        //zero them out
        USER_FRAGS_ON_CYCLE[_cycle][_msgSender()] = 0; // good
        
        //subtract FRAGS from TOTAL on this cycle
        TOTAL_FRAGS_ON_CYCLE[_cycle] = TOTAL_FRAGS_ON_CYCLE[_cycle].sub(fragAmount); // good
        
        //update the current cycle pool stats
        if(_cycle == currentCycle){
            POOL_ON_CYCLE[_cycle] = POOL_ON_CYCLE[_cycle].sub(USDTamount); // good        
            
            //update user count
            USERS_ON_CYCLE[_cycle] = USERS_ON_CYCLE[_cycle].sub(1); // good    
            userExistOnCycle[_cycle][_msgSender()] = false;
        } 

        emit UserWithdraw(USDTamount, _cycle, block.timestamp);
    }


    /****************
    * BOT FUNCTIONS * 
    *****************/
    function BOTwithdraw() external onlyBot isUnlocked {
        //withdraw the pool amount for this investment cycle
        uint256 poolAmount = POOL_ON_CYCLE[currentCycle];
        require (poolAmount > 0,"BotGains: Size zero pool!");
        USDT.transfer(_protocol_storage._tradingWallet(), poolAmount);
        
        //lock the user FUNCTIONS
        locked = true;
        timeLocked = now;

        //emit event to show the amount withdrawn, users, and time
        emit BotWithdraw(poolAmount, USERS_ON_CYCLE[currentCycle], block.timestamp, currentCycle);
    }
    

    function BOTdeposit(uint256 USDTamount) payable onlyBot isNotUnlocked external {
        require(USDT.transferFrom(_msgSender(), address(this), USDTamount));
        
        if(USDTamount == 0){            
            //if the USDT amount here is 0 the previous cycle pool amount can NOT be 0 as well
            if(POOL_ON_CYCLE[currentCycle] != 0)  {
                revert("deposit and pool funds must both be zero or both be non zero");
            }            
        } else{

            //previous pool cycle CANNOT BE ZERO if deposit is not zero!
            if(POOL_ON_CYCLE[currentCycle] == 0){
                revert("deposit and pool funds must both be zero or both be non zero");
            }

            if (POOL_ON_CYCLE[currentCycle] <= USDTamount){ // WIN!
                //subtract USDT amount from pool amount to get profit amount and take 20% 
                uint256 profit = USDTamount.sub(POOL_ON_CYCLE[currentCycle]);
                uint256 forManagement = profit.mul(20).div(100);
                uint256 USDTForPool = USDTamount.sub(forManagement);

                //transfer 20% of profit to management
                transferToManagement(forManagement);

                //caluclate the new fragsPerUSDT on this cycle
                FRAGS_PER_USDT_ON_CYCLE[currentCycle] = TOTAL_FRAGS_ON_CYCLE[currentCycle].div(USDTForPool); // good

                //+1 TO ACCOUNT FOR THE NEXT CYCLE's FRAG CONVERSION
                FRAGS_PER_USDT_ON_CYCLE[currentCycle.add(1)] = fragsPerUSDT;
                
                loss = false;

            } else{ // LOSS!

                //caluclate the new fragsPerUSDT on this cycle
                FRAGS_PER_USDT_ON_CYCLE[currentCycle] = TOTAL_FRAGS_ON_CYCLE[currentCycle].div(USDTamount); // good

                //+1 TO ACCOUNT FOR THE NEXT CYCLE's FRAG CONVERSION
                FRAGS_PER_USDT_ON_CYCLE[currentCycle.add(1)] = fragsPerUSDT;
                
                loss = true;
            }
        }
        
        //increment cycle
        currentCycle = currentCycle.add(1);
        
        //init users
        USERS_ON_CYCLE[currentCycle] = 0;
        
        //unlock
        locked = false;
        timeUnlocked = now;

        emit BotDeposit(USDTamount, currentCycle.sub(1), loss, block.timestamp);
    }
    
    /*internal utils*/
    function incrementUser(address _user) internal {
        if(!userExistOnCycle[currentCycle][_user]){
            userExistOnCycle[currentCycle][_user] = true;
            USERS_ON_CYCLE[currentCycle] = USERS_ON_CYCLE[currentCycle].add(1);
        }
    }


    function transferToDivs(uint256 amount) internal{
        require(USDT.transfer(_protocol_storage._divsFeeWallet(), amount));
    }


    function transferToAdmin(uint256 amount) internal{
        require(USDT.transfer(_protocol_storage._adminFeeWallet(),amount));   
    }


    function transferToManagement(uint256 amount) internal{
        require(USDT.transfer(_protocol_storage._managementFeeWallet(),amount));
    }


    function checkUserLimit(address _user, uint256 amount) view internal{
        if((USER_FRAGS_ON_CYCLE[currentCycle][_user].div(FRAGS_PER_USDT_ON_CYCLE[currentCycle])).add(amount) > _protocol_storage._maxUSDT()){
            revert("This user has reached the maximum limit for deposits!");
        }
        if(POOL_ON_CYCLE[currentCycle].add(amount) > _protocol_storage._maxPoolSize()){
            revert("Maximum amount of USDT reached");
        }
    }


    function calculateUSDT(uint256 fragAmount, uint256 _cycle) internal view returns(uint256){
        return fragAmount.div(FRAGS_PER_USDT_ON_CYCLE[_cycle]);    
    }


    /***********************
    * PUBLIC UTIL FUNCTIONS * 
    ************************/

    function viewFundsAvailable(uint256 _cycle, address _user) external view returns(uint256) {

        uint256 _userFrags = USER_FRAGS_ON_CYCLE[_cycle][_user];

        if(_userFrags == 0){
            return 0;
        }

        uint256 _fragsPerUSDT = FRAGS_PER_USDT_ON_CYCLE[_cycle];
        return _userFrags.div(_fragsPerUSDT);
        
    }


    function viewCurrentlyInvested(address _user) external view returns(uint256) {

        if(USER_FRAGS_ON_CYCLE[currentCycle][_user] == 0){
            return 0;
        }

        return USER_FRAGS_ON_CYCLE[currentCycle][_user].div(FRAGS_PER_USDT_ON_CYCLE[currentCycle]);
    }
    

    function viewPool(uint256 _cycle) external view returns(uint256){
        return POOL_ON_CYCLE[_cycle];
    }
}