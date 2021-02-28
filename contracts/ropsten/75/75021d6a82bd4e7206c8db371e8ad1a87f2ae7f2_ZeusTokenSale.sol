/**
 *Submitted for verification at Etherscan.io on 2021-02-28
*/

pragma solidity >=0.5.12;


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

contract owned {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        require(newOwner != address(this));
        owner = newOwner;
    }
}

contract Token {
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function transfer(address _to, uint256 _value) public returns (bool success);
	function balanceOf(address account) external view returns (uint256);
	
}

contract ZeusTokenSale is owned {
	using SafeMath for uint;
	Token public tokenAddress;
    bool public initialized = false;

	address payable public receiverAddress;
	
	uint public rate = 2000000000000;
	uint public start = 1614304428;
	uint public last = 1640879999;
	
	uint public pre_sale = 40;
    uint public sale_1 = 30;
    uint public sale_2 = 20;
    uint public sale_3 = 15;
    uint public sale_4 = 10;
    uint public sale_5 = 5;
    uint public bonusTokens;
	

	
    event Initialized();
    event WithdrawTokens(address destination, uint256 amount);
    event WithdrawAnyTokens(address tokenAddress, address destination, uint256 amount);
    event WithdrawEther(address destination, uint256 amount);
	
	
	uint early_bird;

	/**
     * Constructor
     *
     * First time rules setup 
     */
    constructor() payable public {
    }


    /**
     * Initialize contract
     *
     * @param _tokenAddress token address
     */
    function init(Token _tokenAddress) onlyOwner public {
        require(!initialized);
        initialized = true;
        tokenAddress = _tokenAddress;
        emit Initialized();
    }


    /**
     * withdrawTokens
     *
     * Withdraw tokens from the contract
     *
     * @param amount is an amount of tokens
     */
    function withdrawTokens(
        uint256 amount
    )
        onlyOwner public
    {
        require(initialized);
        tokenAddress.transfer(msg.sender, amount);
        emit WithdrawTokens(msg.sender, amount);
    }

    /**
     * withdrawAnyTokens
     *
     * Withdraw any tokens from the contract
     *
     * @param _tokenAddress is a token contract address
     * @param amount is an amount of tokens
     */
    function withdrawAnyTokens(
        address _tokenAddress,
        uint256 amount
    )
        onlyOwner public
    {
        Token(_tokenAddress).transfer(msg.sender, amount);
        emit WithdrawAnyTokens(_tokenAddress, msg.sender, amount);
    }
    
    /**
     * withdrawEther
     *
     * Withdraw ether from the contract
     *
     * @param amount is a wei amount 
     */
    function withdrawEther(
        uint256 amount
    )
        onlyOwner public
    {
        msg.sender.transfer(amount);
        emit WithdrawEther(msg.sender, amount);
    }
	
	modifier saleIsOn() {
    require(now > start && now < last);
    _;
	}
	
	function setStart(uint _start) public onlyOwner {
		start = _start;
	}
	
	function setLast(uint _last) public onlyOwner {
		last = _last;
	}
	function setReceiver(address payable _receiverAddress) public onlyOwner {
		receiverAddress = _receiverAddress;
	}
	
	function SetSale(uint _pre_sale, uint _sale_1, uint _sale_2, uint _sale_3, uint _sale_4, uint _sale_5) public onlyOwner {
		pre_sale = _pre_sale;
		sale_1 = _sale_1;
		sale_2 = _sale_2;
		sale_3 = _sale_3;
		sale_4 = _sale_4;
		sale_5 = _sale_5; 
	}
	
	/**
     * Execute transaction
     *
     * @param transactionBytecode transaction bytecode
     */
    function execute(bytes memory transactionBytecode) onlyOwner public {
        require(initialized);
        (bool success, ) = msg.sender.call.value(0)(transactionBytecode);
            require(success);
    }
	
	
	function GetZeus() saleIsOn payable public {

		uint tokens = rate.mul(msg.value).div(1 ether);
		receiverAddress.transfer(msg.value);
		
		uint256 amountTobuy = msg.value;
        uint256 TokenLeft = Token(tokenAddress).balanceOf(address(this));
        require(amountTobuy > 0, "You need to send some Ether");
        require(amountTobuy <= TokenLeft, "Not enough tokens available");
		early_bird = start;
		
		if(now < start)  {
			bonusTokens = tokens.div(100).mul(pre_sale);
		} else if(now >= start && now < start + 7 days) { 	// 1st week
			bonusTokens = tokens.div(100).mul(sale_1);
		} else if(now >= start && now < start + 14 days) { 	// 2nd week
			bonusTokens = tokens.div(100).mul(sale_2);
		} else if(now >= start && now < start + 21 days) { 	// 3rd week
			bonusTokens = tokens.div(100).mul(sale_3);
		} else if(now >= start && now < start + 35 days) { 	// 4th week
			bonusTokens = tokens.div(100).mul(sale_4);
		} else if(now >= start && now < start + 42 days) { 	// 5th week
			bonusTokens = tokens.div(100).mul(sale_5);
		} 
		uint tokensWithBonus = tokens.add(bonusTokens);
        Token(tokenAddress).transfer(msg.sender, tokensWithBonus);
		
	}

	function() external payable {
		GetZeus();
	}
	
}