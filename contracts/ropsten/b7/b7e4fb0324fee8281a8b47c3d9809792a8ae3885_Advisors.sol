pragma solidity ^0.4.0;

contract Ownable {
  address public owner;
  
  constructor() public {
    owner = msg.sender;
  }
  
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  
}


library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

 function mod(uint256 a, uint256 b) internal pure returns (uint256){
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a % b;
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


contract ERC20 {
  function totalSupply() public view returns (uint256);

  function balanceOf(address _who) public view returns (uint256);

  function transfer(address _to, uint256 _value) public  returns (bool);


   function burnTokens(uint256 _value)
        public returns (bool);

  event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
  );

  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}

contract Advisors is ERC20,Ownable{

    using SafeMath for uint256;

       ERC20 _tokenContract;
       uint256 totalAllocatedTokens;
       uint256 tokenReleaseDate;
       bool isSaleStart = false;



    mapping (address => uint256) public allocatedTokens;

        constructor() public{
         _tokenContract = ERC20(0x90f8d966ff7a7dac55caf055b93dd24485fe68ea);
        }

       /*
        * this function add team members to array and also allocate tokens to them.
        */
        function addUsers(address _userAddress, uint256 _tokens) public onlyOwner {

          uint256 contractBalance = _tokenContract.balanceOf(address(this));

          require(contractBalance.sub(totalAllocatedTokens) >= _tokens);
          totalAllocatedTokens = totalAllocatedTokens.add(_tokens);

          //allocate tokens to the user
          allocatedTokens[_userAddress] = allocatedTokens[_userAddress].add(_tokens);
        }


      /*
       *transfer tokens from contract account to the user
       */
      function transfer(address _to, uint256 _value)  public returns (bool) {


          require(tokenReleaseDate!=0);
          require(now > tokenReleaseDate);
          require(msg.sender==_to);
          // get balance of the user , to which the tokens has to be transfer
          uint256 userBalance = _tokenContract.balanceOf(_to);
          uint256 contractBalance = balanceOf(address(this));

         //check that the user would not get more then the allocated tokens
         require((userBalance+_value)<=allocatedTokens[_to]);

         uint256 releasePercent = getTokenReleasePercentage();

         uint256 realeasedTokens = (releasePercent.mul(allocatedTokens[_to]))/100;
         uint256 availableTokens = realeasedTokens-userBalance;
         require(availableTokens>=_value);

           if(!isSaleStart)
                  isSaleStart = true;
          //call transfer method of MyToken contract
          _tokenContract.transfer(_to,_value);
          return true;
    }

    function getTokenReleasePercentage() internal returns(uint256){
         uint256 oneMonthTimestamp = 2678400;
         uint256 quotient;
         uint256 reminder;
         uint256 timeExceed = now.sub(tokenReleaseDate);
         //2678400 are milliseconds in one month

         //calculate the percentage of tokens released
         quotient = timeExceed.div(oneMonthTimestamp);
         reminder = timeExceed.mod(oneMonthTimestamp);
         if(reminder>0)
            quotient = quotient+1;
         uint256 releasePercent = quotient.mul(5);
         return releasePercent;
    }

    /*
     *return allocatedTokens , user balance and available tokens to withdraw
     */
    function getUserDetails(address _userAddress) public constant returns(uint256,uint256,uint256){
        uint256 userAllocation = allocatedTokens[_userAddress];
        uint256 userBalance = _tokenContract.balanceOf(_userAddress);
        uint256 availableTokens;
        if(now>tokenReleaseDate){
         uint256 releasePercent = getTokenReleasePercentage();
         uint256 realeasedTokens = (releasePercent.mul(userAllocation))/100;
         availableTokens = realeasedTokens.sub(userBalance);

        }
        return (userAllocation,userBalance,availableTokens);
    }


    /*
     * set release date of tokens ,
     * only called by admin
     */
    function releaseTokens(uint256 startDate)  public onlyOwner returns (bool) {
          //require(tokenReleaseDate==0);
          require(!isSaleStart);
          require(startDate>now);
          //tokenReleaseDate is equal to startDate plus time limit
          tokenReleaseDate = startDate.add(31536000);
          return true;
    }

    /*
     * burn the tokens of the contract,
     * only called by the owner
     */
    function burnTokens(uint256 _value)  public onlyOwner returns (bool) {
          _tokenContract.burnTokens(_value);
          return true;
    }

     /*
      *return total supply of tokens
      */
     function totalSupply() public constant returns (uint256){
           return _tokenContract.totalSupply();
       }

     /*
      *return balance(no of tokens) of user
      */
       function balanceOf(address _who) public constant returns (uint256){
         return _tokenContract.balanceOf(_who);
       }
}