/**
 *Submitted for verification at Etherscan.io on 2021-08-14
*/

// SPDX-License-Identifier: Unlicensed

pragma solidity 0.6.12;

library SafeMath {

	function add(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a + b;
		require(c >= a, "SafeMath: addition overflow");
		return c;
	}
	
	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
		return sub(a, b, "SafeMath: subtraction overflow");
	}
	
	function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
		require(b <= a, errorMessage);
		uint256 c = a - b;
		return c;
	}
	
	function mul(uint256 a, uint256 b) internal pure returns (uint256) {
		if (a == 0) {
			return 0;
		}
		uint256 c = a * b;
		require(c / a == b, "SafeMath: multiplication overflow");
		return c;
	}
	
	function div(uint256 a, uint256 b) internal pure returns (uint256) {
		return div(a, b, "SafeMath: division by zero");
	}
	
	function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
		require(b > 0, errorMessage);
		uint256 c = a / b;
		return c;
	}
}

contract TestingBNB {
        using SafeMath for *;
		
		uint256 public pool_a_balance;
		uint256 public pool_b_balance;
		uint256 public pool_c_balance;
		
		uint256 public pool_a_investment;
		uint256 public pool_b_investment;
		uint256 public pool_c_investment;
		
		uint256 public pool_b_owner_balance;
		uint256 public pool_c_owner_balance;
		uint256 public pool_d_owner_balance;
		uint256 public pool_e_owner_balance;
		
		uint256 public pool_b_owner_checkpoint;
		uint256 public pool_c_owner_checkpoint;
		uint256 public pool_d_owner_checkpoint;
		uint256 public pool_e_owner_checkpoint;
		
		struct User{
		   uint256 investmentAmount;
		   uint256 poolAShare;
		   uint256 poolBShare;
		   uint256 poolCShare;
		   uint256 depositTime;
		   uint256 directsIncome;
		   uint256 passiveReferralIncome;
		   uint256 incomeLimitLeft;
		   uint256 referralCount;
		   address referrer;
		   uint256 checkpoint;
		}
		
        mapping (address => User) public player;
		
        /****************************  EVENTS   *****************************************/
        event registerUserEvent(address indexed _playerAddress, address indexed _referrer);
        event investmentEvent(address indexed _playerAddress, uint256 indexed _amount);
        event referralCommissionEvent(address indexed _playerAddress, address indexed _referrer, uint256 indexed amount, uint256 _type);
        event withdrawEvent(address indexed _playerAddress, uint256 indexed amount, uint256 indexed timeStamp);
		
		address payable public pool_a_owner;
		address payable public pool_b_owner;
		address payable public pool_c_owner;
		address payable public pool_d_owner;
		address payable public pool_e_owner;
		
        constructor(address payable pool_a, address payable pool_b, address payable pool_c, address payable pool_d, address payable pool_e, address payable masterAccount) public {
           pool_a_owner = pool_a;
           pool_b_owner = pool_b;
		   pool_c_owner = pool_c;
		   pool_d_owner = pool_d;
		   pool_e_owner = pool_e;
		   player[masterAccount].depositTime = block.timestamp;
		   
		   pool_b_owner_checkpoint = block.timestamp;
		   pool_c_owner_checkpoint = block.timestamp;
		   pool_d_owner_checkpoint = block.timestamp;
		   pool_e_owner_checkpoint = block.timestamp;
        }
		
        function isUser(address _addr) public view returns (bool) {
            return player[_addr].investmentAmount > 0;
        }
		
        modifier isMinimumAmount(uint256 _bnb) {
            require(_bnb >= 1 * 10**17, "Minimum contribution amount is 0.1 BNB");
			_;
        }
		
		modifier isMaximumAmount(uint256 _bnb) {
            require(_bnb <= 500 * 10**18, "maximum contribution amount is 500 BNB");
			_;
        }
		
		
        function registerUser(address referrer) public isMinimumAmount(msg.value) isMaximumAmount(msg.value) payable 
		{
		    require(player[referrer].depositTime > 0, "referrer not valid");
            uint256 amount = msg.value;
            if(player[msg.sender].investmentAmount <= 0) 
			{
                player[msg.sender].referrer = referrer;
                player[referrer].referralCount = player[referrer].referralCount.add(1);
            }
            else 
			{
				referrer = player[msg.sender].referrer;
            }
			
			player[msg.sender].depositTime = block.timestamp;
			player[msg.sender].investmentAmount = player[msg.sender].investmentAmount.add(amount);
			player[msg.sender].incomeLimitLeft = player[msg.sender].incomeLimitLeft.add(amount.mul(2));
			player[msg.sender].checkpoint = block.timestamp.add(1 days);
			player[referrer].passiveReferralIncome = player[referrer].passiveReferralIncome.add(amount.mul(8).div(100));
			directsReferralBonus(msg.sender, amount);
			emit registerUserEvent(msg.sender, referrer);
			
			pool_a_balance = pool_a_balance.add(amount.mul(16).div(100));
			pool_b_balance = pool_b_balance.add(amount.mul(8).div(100));
			pool_c_balance = pool_c_balance.add(amount.mul(8).div(100));
			
			pool_b_owner_balance = pool_b_owner_balance.add(amount.mul(7).div(100));
			pool_c_owner_balance = pool_c_owner_balance.add(amount.mul(7).div(100));
			pool_d_owner_balance = pool_d_owner_balance.add(amount.mul(3).div(100));
			pool_e_owner_balance = pool_e_owner_balance.add(amount.mul(3).div(100));
			
			if(amount >= 30 * 10**18)
			{
				pool_a_investment = pool_a_investment.add(amount.div(4));
				pool_b_investment = pool_b_investment.add(amount.div(2));
				pool_c_investment = pool_c_investment.add(amount);
				
				player[msg.sender].poolAShare = player[msg.sender].investmentAmount.div(4);
				player[msg.sender].poolBShare = player[msg.sender].investmentAmount.div(2);
				player[msg.sender].poolCShare = player[msg.sender].investmentAmount;

			}
			else if(amount >= 15 * 10**18)
			{
				pool_a_investment = pool_a_investment.add(amount.div(2));
				pool_b_investment = pool_b_investment.add(amount);
				
				player[msg.sender].poolAShare = player[msg.sender].investmentAmount.div(2);
				player[msg.sender].poolBShare = player[msg.sender].investmentAmount;
				player[msg.sender].poolCShare = 0;
			}
			else
			{
			    pool_a_investment = pool_a_investment.add(amount);
				
				player[msg.sender].poolAShare = player[msg.sender].investmentAmount;
				player[msg.sender].poolBShare = 0;
				player[msg.sender].poolCShare = 0;
			}
			pool_a_owner.transfer(amount.mul(30).div(100));
			emit investmentEvent(msg.sender, amount);
        }
		
		function reInvestUser(address user, uint256 amount) private
		{
		    require(amount >= 1 * 10**17, "Minimum contribution amount is 0.1 BNB");
			require(amount <= 500 * 10**18, "maximum contribution amount is 500 BNB");
			
			address referrer = player[user].referrer;
			player[user].depositTime = block.timestamp;
			player[user].investmentAmount = player[user].investmentAmount.add(amount);
			player[user].incomeLimitLeft = player[user].incomeLimitLeft.add(amount.mul(2));
			player[user].checkpoint = block.timestamp.add(1 days);
			player[referrer].passiveReferralIncome = player[referrer].passiveReferralIncome.add(amount.mul(8).div(100));
			
			directsReferralBonus(user, amount);
			emit registerUserEvent(user, referrer);
			
			pool_a_balance = pool_a_balance.add(amount.mul(16).div(100));
			pool_b_balance = pool_b_balance.add(amount.mul(8).div(100));
			pool_c_balance = pool_c_balance.add(amount.mul(8).div(100));
			
			pool_b_owner_balance = pool_b_owner_balance.add(amount.mul(7).div(100));
			pool_c_owner_balance = pool_c_owner_balance.add(amount.mul(7).div(100));
			pool_d_owner_balance = pool_d_owner_balance.add(amount.mul(3).div(100));
			pool_e_owner_balance = pool_e_owner_balance.add(amount.mul(3).div(100));
			
			if(player[user].investmentAmount >= 30 * 10**18)
			{
				pool_a_investment = pool_a_investment.add(amount.div(4));
				pool_b_investment = pool_b_investment.add(amount.div(2));
				pool_c_investment = pool_c_investment.add(amount);
				
				player[user].poolAShare = player[user].investmentAmount.div(4);
				player[user].poolBShare = player[user].investmentAmount.div(2);
				player[user].poolCShare = player[user].investmentAmount;
			}
			else if(player[user].investmentAmount >= 15 * 10**18)
			{
				pool_a_investment = pool_a_investment.add(amount.div(2));
				pool_b_investment = pool_b_investment.add(amount);
				
				player[user].poolAShare = player[user].investmentAmount.div(2);
				player[user].poolBShare = player[user].investmentAmount;
				player[user].poolCShare = 0;
			}
			else
			{
			    pool_a_investment = pool_a_investment.add(amount);
				
				player[user].poolAShare = player[user].investmentAmount;
				player[user].poolBShare = 0;
				player[user].poolCShare = 0;
			}
			
			pool_a_owner.transfer(amount.mul(30).div(100));
			emit investmentEvent(user, amount);
        }
		
        function directsReferralBonus(address _playerAddress, uint256 amount) private 
		{
            address _nextReferrer = player[_playerAddress].referrer;
            uint i;
            for(i=0; i < 3; i++) 
			{
                if(_nextReferrer != address(0x0)) 
				{
					if(i == 0) 
					{
						 player[_nextReferrer].directsIncome = player[_nextReferrer].directsIncome.add(amount.mul(7).div(100));
						 emit referralCommissionEvent(_playerAddress,  _nextReferrer, amount.mul(7).div(100), 1);
					}
					else if(i == 1 ) 
					{
						player[_nextReferrer].directsIncome = player[_nextReferrer].directsIncome.add(amount.mul(2).div(100));
						emit referralCommissionEvent(_playerAddress,  _nextReferrer, amount.mul(2).div(100), 2);
					}
					else 
					{
						player[_nextReferrer].directsIncome = player[_nextReferrer].directsIncome.add(amount.mul(1).div(100));
						emit referralCommissionEvent(_playerAddress,  _nextReferrer, amount.mul(1).div(100), 3);
					}
                }
                else 
				{
                    break;
                }
                _nextReferrer = player[_nextReferrer].referrer;
            }
        }
		
        function withdrawEarnings() public 
		{
            require(player[msg.sender].incomeLimitLeft > 0, "limit not available");
			
			(uint256 poolAIncome, uint256 poolBIncome, uint256 poolCIncome) = this.poolIncome(msg.sender);
			(uint256 passiveIncome) = this.passiveReferralIncome(msg.sender);
			uint256 to_payout;
			
			//Pool A Income
            if(poolAIncome > 0) 
			{
                if(poolAIncome > player[msg.sender].incomeLimitLeft)
				{
                    poolAIncome = player[msg.sender].incomeLimitLeft;
                }
                pool_a_balance = pool_a_balance.sub(poolAIncome);
                player[msg.sender].incomeLimitLeft = player[msg.sender].incomeLimitLeft.sub(poolAIncome);
				to_payout = to_payout.add(poolAIncome);
            }
			
			//Pool B Income
			if(poolBIncome > 0 && player[msg.sender].incomeLimitLeft > 0) 
			{
                if(poolBIncome > player[msg.sender].incomeLimitLeft)
				{
                    poolBIncome = player[msg.sender].incomeLimitLeft;
                }
                pool_b_balance = pool_b_balance.sub(poolBIncome);
                player[msg.sender].incomeLimitLeft = player[msg.sender].incomeLimitLeft.sub(poolBIncome);
				to_payout = to_payout.add(poolBIncome);
            }
			
			//Pool C Income
			if(poolCIncome > 0 && player[msg.sender].incomeLimitLeft > 0) 
			{
                if(poolCIncome > player[msg.sender].incomeLimitLeft)
				{
                    poolCIncome = player[msg.sender].incomeLimitLeft;
                }
                pool_c_balance = pool_c_balance.sub(poolCIncome);
                player[msg.sender].incomeLimitLeft = player[msg.sender].incomeLimitLeft.sub(poolCIncome);
				to_payout = to_payout.add(poolCIncome);
            }
			
			//Passive Bonus
            if(player[msg.sender].incomeLimitLeft > 0 && passiveIncome > 0) 
			{
                if(passiveIncome > player[msg.sender].incomeLimitLeft)
				{
                    passiveIncome = player[msg.sender].incomeLimitLeft;
                }
				player[msg.sender].passiveReferralIncome = player[msg.sender].passiveReferralIncome.sub(passiveIncome);
                player[msg.sender].incomeLimitLeft = player[msg.sender].incomeLimitLeft.sub(passiveIncome);
				to_payout = to_payout.add(passiveIncome);
            }
			
            //Sponsor Bonus
            if(player[msg.sender].incomeLimitLeft > 0 && player[msg.sender].directsIncome > 0) 
			{
                uint256 direct_bonus = player[msg.sender].directsIncome;
                if(direct_bonus > player[msg.sender].incomeLimitLeft) 
				{
                    direct_bonus = player[msg.sender].incomeLimitLeft;
                }
                player[msg.sender].directsIncome = player[msg.sender].directsIncome.sub(direct_bonus);
                player[msg.sender].incomeLimitLeft = player[msg.sender].incomeLimitLeft.sub(direct_bonus);
				to_payout = to_payout.add(direct_bonus);
            }
			
            require(to_payout > 0, "Zero payout");
			player[msg.sender].checkpoint = block.timestamp.add(1 days);
			
			if(player[msg.sender].incomeLimitLeft==0)
			{
			    pool_a_investment = pool_a_investment.sub(player[msg.sender].poolAShare); 
				pool_b_investment = pool_b_investment.sub(player[msg.sender].poolBShare); 
				pool_c_investment = pool_c_investment.sub(player[msg.sender].poolCShare);
				
				player[msg.sender].poolAShare = 0;
				player[msg.sender].poolBShare = 0;
				player[msg.sender].poolCShare = 0;
				
				player[msg.sender].investmentAmount = 0;
			}
			
			address payable senderAddr = address(uint160(msg.sender));
            senderAddr.transfer(to_payout);
            emit withdrawEvent(msg.sender, to_payout, block.timestamp);
        }
		
		function withdrawReinvest() public 
		{
            require(player[msg.sender].incomeLimitLeft > 0, "limit not available");
			
			(uint256 poolAIncome, uint256 poolBIncome, uint256 poolCIncome) = this.poolIncome(msg.sender);
			(uint256 passiveIncome) = this.passiveReferralIncome(msg.sender);
			uint256 to_payout;
			
			//Pool A Income
            if(poolAIncome > 0) 
			{
                if(poolAIncome > player[msg.sender].incomeLimitLeft)
				{
                    poolAIncome = player[msg.sender].incomeLimitLeft;
                }
                pool_a_balance = pool_a_balance.sub(poolAIncome);
                player[msg.sender].incomeLimitLeft = player[msg.sender].incomeLimitLeft.sub(poolAIncome);
				to_payout = to_payout.add(poolAIncome);
            }
			
			//Pool B Income
			if(poolBIncome > 0 && player[msg.sender].incomeLimitLeft > 0) 
			{
                if(poolBIncome > player[msg.sender].incomeLimitLeft)
				{
                    poolBIncome = player[msg.sender].incomeLimitLeft;
                }
                pool_b_balance = pool_b_balance.sub(poolBIncome);
                player[msg.sender].incomeLimitLeft = player[msg.sender].incomeLimitLeft.sub(poolBIncome);
				to_payout = to_payout.add(poolBIncome);
            }
			
			//Pool C Income
			if(poolCIncome > 0 && player[msg.sender].incomeLimitLeft > 0) 
			{
                if(poolCIncome > player[msg.sender].incomeLimitLeft)
				{
                    poolCIncome = player[msg.sender].incomeLimitLeft;
                }
                pool_c_balance = pool_c_balance.sub(poolCIncome);
                player[msg.sender].incomeLimitLeft = player[msg.sender].incomeLimitLeft.sub(poolCIncome);
				to_payout = to_payout.add(poolCIncome);
            }
			
			//Passive Bonus
            if(player[msg.sender].incomeLimitLeft > 0 && passiveIncome > 0) 
			{
                if(passiveIncome > player[msg.sender].incomeLimitLeft)
				{
                    passiveIncome = player[msg.sender].incomeLimitLeft;
                }
				player[msg.sender].passiveReferralIncome = player[msg.sender].passiveReferralIncome.sub(passiveIncome);
                player[msg.sender].incomeLimitLeft = player[msg.sender].incomeLimitLeft.sub(passiveIncome);
				to_payout = to_payout.add(passiveIncome);
            }
			
            //Sponsor Bonus
            if(player[msg.sender].incomeLimitLeft > 0 && player[msg.sender].directsIncome > 0) 
			{
                uint256 direct_bonus = player[msg.sender].directsIncome;
                if(direct_bonus > player[msg.sender].incomeLimitLeft) 
				{
                    direct_bonus = player[msg.sender].incomeLimitLeft;
                }
                player[msg.sender].directsIncome = player[msg.sender].directsIncome.sub(direct_bonus);
                player[msg.sender].incomeLimitLeft = player[msg.sender].incomeLimitLeft.sub(direct_bonus);
				to_payout = to_payout.add(direct_bonus);
            }
			
            require(to_payout > 0, "Zero payout");
			player[msg.sender].checkpoint = block.timestamp.add(1 days);
			
			if(player[msg.sender].incomeLimitLeft==0)
			{
			    pool_a_investment = pool_a_investment.sub(player[msg.sender].poolAShare); 
				pool_b_investment = pool_b_investment.sub(player[msg.sender].poolBShare); 
				pool_c_investment = pool_c_investment.sub(player[msg.sender].poolCShare); 
				
				player[msg.sender].poolAShare = 0;
				player[msg.sender].poolBShare = 0;
				player[msg.sender].poolCShare = 0;
				
				player[msg.sender].investmentAmount = 0;
			}
			
			address payable senderAddr = address(uint160(msg.sender));
			reInvestUser(senderAddr, to_payout);
			
            emit withdrawEvent(msg.sender, to_payout, block.timestamp);
        }
		
        function poolIncome(address _addr) view external returns(uint256, uint256, uint256){
		    uint256 poolAIncome;
			uint256 poolBIncome;
			uint256 poolCIncome;
		    if(block.timestamp > player[_addr].checkpoint && player[_addr].incomeLimitLeft > 0)
			{
				uint256 poolAShare = player[_addr].poolAShare;
				uint256 poolBShare = player[_addr].poolBShare;
				uint256 poolCShare = player[_addr].poolCShare;
				if(poolAShare > 0 && pool_a_balance > 0 && pool_a_investment > 0)
				{
				    poolAIncome = pool_a_balance.mul(poolAShare.mul(100).div(pool_a_investment)).div(100).div(10);
				}
				if(poolBShare > 0 && pool_b_balance > 0 && pool_b_investment > 0)
				{
				    poolBIncome = pool_b_balance.mul(poolBShare.mul(100).div(pool_b_investment)).div(100).div(10);
				}
				if(poolCShare > 0 && pool_c_balance > 0 && pool_c_investment > 0)
				{
				    poolCIncome = pool_c_balance.mul(poolCShare.mul(100).div(pool_c_investment)).div(100).div(10);
				}
			}
			return (poolAIncome, poolBIncome, poolCIncome);
        }
		
		function passiveReferralIncome(address _addr) view external returns(uint256)
		{
		    uint256 passiveIncome;
			if(block.timestamp > player[_addr].checkpoint && player[_addr].incomeLimitLeft > 0)
			{
			    passiveIncome = player[_addr].passiveReferralIncome.mul(1).div(100).mul((block.timestamp.sub(player[_addr].checkpoint))/1 days);
			}
			return passiveIncome;
        }
		
		function withdrawPoolBBalance() public 
		{
		   require(pool_b_owner_balance > 0, "some error found");
		   require(msg.sender==pool_b_owner, "some error found");
		   (uint256 amount) = this.poolbwithdrawable();
		   
		   pool_b_owner_checkpoint = block.timestamp.add(1 days);
		   pool_b_owner_balance = pool_b_owner_balance.sub(amount);
		   pool_b_owner.transfer(amount);
		   emit withdrawEvent(msg.sender, amount, block.timestamp);
        }
		
		function withdrawPoolCBalance() public 
		{
		   require(pool_c_owner_balance > 0, "some error found");
		   require(msg.sender==pool_c_owner, "some error found");
		   (uint256 amount) = this.poolcwithdrawable();
		   
		   pool_c_owner_checkpoint = block.timestamp.add(1 days);
		   pool_c_owner_balance = pool_c_owner_balance.sub(amount);
		   pool_c_owner.transfer(amount);
		   emit withdrawEvent(msg.sender, amount, block.timestamp);
        }
		
		function withdrawPoolDBalance() public 
		{
		   require(pool_d_owner_balance > 0, "some error found");
		   require(msg.sender==pool_d_owner, "some error found");
		   (uint256 amount) = this.pooldwithdrawable();
		   
		   pool_d_owner_checkpoint = block.timestamp.add(1 days);
		   pool_d_owner_balance = pool_d_owner_balance.sub(amount);
		   pool_d_owner.transfer(amount);
		   emit withdrawEvent(msg.sender, amount, block.timestamp);
        }
		
		function withdrawPoolEBalance() public 
		{
		   require(pool_e_owner_balance > 0, "some error found");
		   require(msg.sender==pool_e_owner, "some error found");
		   (uint256 amount) = this.poolewithdrawable();
		   
		   pool_e_owner_checkpoint = block.timestamp.add(1 days);
		   pool_e_owner_balance = pool_e_owner_balance.sub(amount);
		   pool_e_owner.transfer(amount);
		   emit withdrawEvent(msg.sender, amount, block.timestamp);
        }
		
		function poolbwithdrawable() view external returns(uint256)
		{
		    uint256 withdrawable;
			if(block.timestamp > pool_b_owner_checkpoint && pool_b_owner_balance > 0)
			{
			    withdrawable = pool_b_owner_balance.mul(4).div(100).mul((block.timestamp.sub(pool_b_owner_checkpoint))/1 days);
			    if(withdrawable > pool_b_owner_balance)
				{
				   withdrawable = pool_b_owner_balance;
				}
			}
			return withdrawable;
        }
		
		function poolcwithdrawable() view external returns(uint256)
		{
		    uint256 withdrawable;
			if(block.timestamp > pool_c_owner_checkpoint && pool_c_owner_balance > 0)
			{
			    withdrawable = pool_c_owner_balance.mul(4).div(100).mul((block.timestamp.sub(pool_c_owner_checkpoint))/1 days);
			    if(withdrawable > pool_c_owner_balance)
				{
				   withdrawable = pool_c_owner_balance;
				}
			}
			return withdrawable;
        }
		
		function pooldwithdrawable() view external returns(uint256)
		{
		    uint256 withdrawable;
			if(block.timestamp > pool_d_owner_checkpoint && pool_d_owner_balance > 0)
			{
			    withdrawable = pool_d_owner_balance.mul(4).div(100).mul((block.timestamp.sub(pool_d_owner_checkpoint))/1 days);
				if(withdrawable > pool_d_owner_balance)
				{
				   withdrawable = pool_d_owner_balance;
				}
			}
			return withdrawable;
        }
		
		function poolewithdrawable() view external returns(uint256)
		{
		    uint256 withdrawable;
			if(block.timestamp > pool_e_owner_checkpoint && pool_e_owner_balance > 0)
			{
			    withdrawable = pool_e_owner_balance.mul(4).div(100).mul((block.timestamp.sub(pool_e_owner_checkpoint))/1 days);
				if(withdrawable > pool_e_owner_balance)
				{
				   withdrawable = pool_e_owner_balance;
				}
			}
			return withdrawable;
        }
}