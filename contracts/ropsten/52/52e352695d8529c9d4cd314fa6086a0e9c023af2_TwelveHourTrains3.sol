pragma solidity ^0.4.25;

/**
*
12HourTrains - 3% every 12 hours. Want to get quick ETH? Try our new Dice game.
https://12hourtrains.github.io/
Version 3
*/
contract TwelveHourTrains3 {

    using SafeMath for uint256;

    mapping(address => uint256) investments;
    mapping(address => uint256) joined;
    mapping(address => uint256) withdrawals;
    mapping(address => uint256) referrer;

    uint256 public step = 100;
    uint256 public minimum = 10 finney;
    uint256 public stakingRequirement = 2 ether;
    address public ownerWallet;
    address public owner;
    uint256 private randNonce = 0;

    /**
    * @dev Modifiers
    */

    modifier onlyOwner() 
    {
        require(msg.sender == owner);
        _;
    }
    modifier disableContract()
    {
        require(tx.origin == msg.sender);
        _;
    }
    /**
    * @dev Event
    */
    event Invest(address investor, uint256 amount);
    event Withdraw(address investor, uint256 amount);
    event Bounty(address hunter, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Lottery(address player, uint256 lotteryNumber, uint256 amount, uint256 result,bool isWin);
    /**
    * @dev ?onstructor Sets the original roles of the contract
    */

    constructor() public 
    {
        owner = msg.sender;
        ownerWallet = msg.sender;
    }

    /**
    * @dev Allows current owner to transfer control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    * @param newOwnerWallet The address to transfer ownership to.
    */
    function transferOwnership(address newOwner, address newOwnerWallet) public onlyOwner 
    {
        require(newOwner != address(0));

        owner = newOwner;
        ownerWallet = newOwnerWallet;

        emit OwnershipTransferred(owner, newOwner);
    }

    /**
    * @dev Investments
    */
    function () public payable 
    {
        buy(0x0);
    }

    function buy(address _referredBy) public payable 
    {
        require(msg.value >= minimum);

        address _customerAddress = msg.sender;

        if(
           // is this a referred purchase?
           _referredBy != 0x0000000000000000000000000000000000000000 &&

           // no cheating!
           _referredBy != _customerAddress &&

           // does the referrer have at least X whole tokens?
           // i.e is the referrer a godly chad masternode
           investments[_referredBy] >= stakingRequirement
       ){
           // wealth redistribution
           referrer[_referredBy] = referrer[_referredBy].add(msg.value.mul(5).div(100));
       }

       if (investments[msg.sender] > 0){
           if (withdraw()){
               withdrawals[msg.sender] = 0;
           }
       }
       investments[msg.sender] = investments[msg.sender].add(msg.value);
       joined[msg.sender] = block.timestamp;
       ownerWallet.transfer(msg.value.mul(5).div(100));

       emit Invest(msg.sender, msg.value);
    }
    //--------------------------------------------------------------------------------------------
    // LOTTERY
    //--------------------------------------------------------------------------------------------
    /**
    * @param _value number in array [1,2,3]
    */
    function lottery(uint256 _value) public payable disableContract
    {
        uint256 random = getRandomNumber(msg.sender) + 1;
        bool isWin = false;
        if (random == _value) {
            isWin = true;
            uint256 prize = msg.value.mul(249).div(100);
            if (prize <= address(this).balance) {
                msg.sender.transfer(prize);
            }
        }
        ownerWallet.transfer(msg.value.mul(5).div(100));
        
        emit Lottery(msg.sender, _value, msg.value, random, isWin);
    }

    /**
    * @dev Evaluate current balance
    * @param _address Address of investor
    */
    function getBalance(address _address) view public returns (uint256) {
        uint256 minutesCount = now.sub(joined[_address]).div(1 minutes);
        uint256 percent = investments[_address].mul(step).div(100);
        uint256 different = percent.mul(minutesCount).div(24000);
        uint256 balance = different.sub(withdrawals[_address]);

        return balance;
    }

    /**
    * @dev Withdraw dividends from contract
    */
    function withdraw() public returns (bool){
        require(joined[msg.sender] > 0);
        uint256 balance = getBalance(msg.sender);
        if (address(this).balance > balance){
            if (balance > 0){
                withdrawals[msg.sender] = withdrawals[msg.sender].add(balance);
                msg.sender.transfer(balance);
                emit Withdraw(msg.sender, balance);
            }
            return true;
        } else {
            return false;
        }
    }
    /**
    * @dev Bounty reward
    */
    function bounty() public {
        uint256 refBalance = checkReferral(msg.sender);
        if(refBalance >= minimum) {
             if (address(this).balance > refBalance) {
                referrer[msg.sender] = 0;
                msg.sender.transfer(refBalance);
                emit Bounty(msg.sender, refBalance);
             }
        }
    }

    /**
    * @dev Gets balance of the sender address.
    * @return An uint256 representing the amount owned by the msg.sender.
    */
    function checkBalance() public view returns (uint256) {
        return getBalance(msg.sender);
    }

    /**
    * @dev Gets withdrawals of the specified address.
    * @param _investor The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function checkWithdrawals(address _investor) public view returns (uint256) 
    {
        return withdrawals[_investor];
    }
    /**
    * @dev Gets investments of the specified address.
    * @param _investor The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function checkInvestments(address _investor) public view returns (uint256) 
    {
        return investments[_investor];
    }
    
    /**
    * @dev Gets referrer balance of the specified address.
    * @param _hunter The address of the referrer
    * @return An uint256 representing the referral earnings.
    */
    function checkReferral(address _hunter) public view returns (uint256) 
    {
        return referrer[_hunter];
    }
    function checkContractBalance() public view returns (uint256) 
    {
        return address(this).balance;
    }
    //----------------------------------------------------------------------------------
    // INTERNAL FUNCTION
    //----------------------------------------------------------------------------------
    function getRandomNumber(address _addr) public view returns (uint256 randomNumber) 
    {
        randNonce++;
        randomNumber = uint256(keccak256(abi.encodePacked(now, _addr, randNonce, block.coinbase, block.number))) % 3;
        return randomNumber;
    }

}

 


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}