pragma solidity ^0.4.24;

/**
 * Bwenox.Network!
 *
 * Hey, 
 * 
 * You know the rules of ponzi already,
 * but let me briefly explain how this one works ;)
 * 
 * This is your personal 45 days magic piggy bank!
 * 
 * 1. Send fixed amount of ether every 24 hours (5900 blocks).
 * 2. With every new transaction collect exponentially greater return!
 * 3. Keep sending the same amount of ether! (can&#39;t trick the code, bro)
 * 4. Don&#39;t send too often (early transactions will be rejected, uh oh)
 * 5. Don&#39;t be late, you won&#39;t loose your %, but who wants to be the last?
 *  
 * Play by the rules and save up to 170%!
 *
 * Gas limit: 150 000 (only the first time, average ~ 50 000)
 * Gas price: https://ethgasstation.info/
 *
 */
 
contract Owned {
    address public owner;
    function Owned() {
        owner = msg.sender;
    }
    modifier onlyOwner() {
        assert(msg.sender == owner);
        _;
    }
    
}
contract BwenoxNet is Owned {
    string public constant name = " Bwenox ↓ Network ↓ Investment";
    
    string public constant symbol = "GetEth";
    

    struct User {
        uint value;
        uint index;
        uint atBlock;
    }

    mapping (address => User) public users;
    
    uint public total;
    uint public project;
    uint public team;
   
    address public teamAddress;
    address public projectAddress;

    constructor(address _projectAddress, address _teamAddress) public {
        projectAddress = _projectAddress;
        teamAddress = _teamAddress;
    }
    
    function balance() internal constant returns (uint256 amount) {
		// msg.value is the amount of Ether sent by the transaction.
		return total - msg.value;
	}

    function () public payable {
        require(msg.value == 0.00001111 ether || (msg.value >= 0.01 ether && msg.value <= 5 ether), "Min: 0.01 ether, Max: 5 ether, Exit: 0.00001111 eth");

        User storage user = users[msg.sender]; // this is you

        if (msg.value != 0.00001111 ether) {
            total += msg.value;                 // total 
            project += msg.value / 100;    // 10% game
            team += msg.value / 50;            // 0.5% team
            
            if (user.value == 0) { 
                user.value = msg.value;
                user.atBlock = block.number;
                user.index = 1;     
            } else {
                require(msg.value == user.value, "Amount should be the same");
                require(block.number - user.atBlock >= 5900, "Too soon, try again later");

                uint idx = ++user.index;
                
                if (idx == 365) {
                    user.value = 0; // game over for you, my friend!
                } else {
                    // if you are late for more than 4 hours (984 blocks)
                    // then next deposit/payment will be delayed accordingly
                    if (block.number - user.atBlock - 5900 < 984) { 
                        user.atBlock += 5900;
                    } else {
                        user.atBlock = block.number - 984;
                    }
                }

                // sprinkle that with some magic numbers and voila
                msg.sender.transfer(msg.value * idx * idx * (24400 - 500 * msg.value / 1 ether) / 10000000);
            }
        } else {
            require(user.index <= 10, "It&#39;s too late to request a refund at this point");

            msg.sender.transfer(user.index * user.value * 70 / 100);
            user.value = 0;
        }
        
    }

    /**
     * This one is easy, claim reserved ether for the team or project
     * 
     * 
     * 
     */ 
     
    
     
     
    function claim(uint amount) public {
        if (msg.sender == projectAddress) {
            require(amount > 0 && amount <= project, "Can&#39;t claim more than was reserved");

            project -= amount;
            msg.sender.transfer(amount);
        } else 
        if (msg.sender == teamAddress) {
            require(amount > 0 && amount <= team, "Can&#39;t claim more than was reserved");

            team -= amount;
            msg.sender.transfer(amount);
        }
    }
}