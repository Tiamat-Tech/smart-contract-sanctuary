/**
 *Submitted for verification at Etherscan.io on 2021-12-27
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ERC20 {
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool); 
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
}

contract Sale {

	address private Owner;
	address public TokenSale;
	uint256 public TimetoStartBuy;
	uint256 public TimetoEndBuy;
    address private _usdt = 0xD25DdeD75e28aBee8797485FaeC783943cB84e84;

	mapping (address => bool) public isbuyer;
	mapping (address => uint256) public buyamount;
	mapping (address => uint256) public remainclaim;
	mapping (uint256 => uint256) internal timer;
	mapping (uint256 => uint256) internal percentage;
	mapping (address => uint256) internal usermonthclaim;


	event BuyTokensWithUSDT(address indexed purchaser, uint256 tokensBought, uint256 tokensSold);
	event ClaimTokens(address indexed beneficiary, uint256 amount, uint256 remain);
	event Widthdraw_USDT(address indexed to, uint256 amount);

	modifier isAdmin {
		require(Owner == msg.sender, "You aren't an Owner.");
		_;
	}

	constructor(address _tokensale,uint256 startbuy, uint256 endbuy) {
		Owner = msg.sender;
		TimetoStartBuy = startbuy;
		TimetoEndBuy = endbuy;
		for (uint256 i = 0; i < 18; i++) {
			timer[i] = endbuy + (60*60*24*(i+2+1));
			if(i <= 6) {
				percentage[i] = 25;
			} else if(i<=13 && i > 6) {
				percentage[i] = 50;
			} else if(i<18 && i > 13) {
				percentage[i] = 100;
			}
		}
		TokenSale = _tokensale;
	}

	function buyTokensWithUSDT(uint256 value) public  {
		require(block.timestamp >= TimetoStartBuy && block.timestamp <= TimetoEndBuy ,"Token sale not start yet, or already end");
		require(ERC20(_usdt).allowance(msg.sender, address(this)) >= value, "Not enough allowance");
		require(ERC20(_usdt).balanceOf(msg.sender) >= value, "Not enough balance");

	    uint256 rate;
        if (((value*17/1000)/10**ERC20(_usdt).decimals()) >= 150000) { 
			assembly { 
				rate := 17
			}
		}else if (((value*17/1000)/10**ERC20(_usdt).decimals()) < 150000) { 
			assembly  {
				rate := 20
			}
		}

		uint256 realgetis = ((value*rate)/1000)/10**ERC20(_usdt).decimals();

		require(buyamount[msg.sender] <= 2000000,"Limit buy is 2000000");
		require(buyamount[msg.sender] + realgetis <= 2000000,"Limit buy is 2000000");
		ERC20(_usdt).transferFrom(msg.sender,address(this), value); // Receive Money.
		buyamount[msg.sender] += realgetis;
		remainclaim[msg.sender] += realgetis;
		usermonthclaim[msg.sender] = 0;

		emit BuyTokensWithUSDT(msg.sender, value/10**ERC20(address(0)).decimals(),realgetis); // params กลาง address เหรียญเรา
	}

	function Claim() public {
		require(usermonthclaim[msg.sender] < 18,"Your claim all at now.");
		require(isbuyer[msg.sender] == true, "You can't claim tokens");
		require(block.timestamp >= timer[usermonthclaim[msg.sender]], "Not This time.");
		uint256 value = ((buyamount[msg.sender])*(percentage[usermonthclaim[msg.sender]]/10))*10**ERC20(TokenSale).decimals();
		ERC20(TokenSale).transfer(msg.sender, value);
		uint256 valuenodecimals = ((buyamount[msg.sender])*(percentage[usermonthclaim[msg.sender]]/10));
		remainclaim[msg.sender] -= valuenodecimals;
		usermonthclaim[msg.sender] += 1;

		emit ClaimTokens(msg.sender, valuenodecimals, remainclaim[msg.sender]);
	}

	function WidthdrawUSDT(address to,uint256 value) public isAdmin { // Secure of Widthdraw
		ERC20(_usdt).transfer(to,value);

		emit Widthdraw_USDT(to,value);
	}
}