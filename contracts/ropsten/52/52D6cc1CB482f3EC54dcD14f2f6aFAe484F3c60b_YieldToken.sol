// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <= 0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ILions.sol";

contract YieldToken is ERC20("SexyToken", "SEXY") {
	using SafeMath for uint256;
    using Address for address;

	uint256 constant public BASE_RATE = 1 ether; 
	uint256 constant public INITIAL_ISSUANCE = 10 ether;

    uint256 constant public REWARD_SEPARATOR = 600;

    mapping(address => mapping(address => uint256)) rewards;
    mapping(address => mapping(address => uint256)) lastUpdates;

    mapping(address => uint256) rewardsEnd;
    address[] contracts;

    address owner; 

	event RewardPaid(address indexed user, uint256 reward);

    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier isContract() {
        require(msg.sender.isContract(), "Address isn`t a contract");
        _;
    }

    modifier isValidAddress() {
        bool _found;
        for(uint i=0; i<contracts.length; i++) {
            if(contracts[i] == msg.sender) {
                _found = true;
                break;
            }
        }

        require(_found, "Address is not one of permissioned addresses");
        _;
    }

	constructor(address _contract) {
        contracts.push(_contract);
        owner = msg.sender;
        
        rewardsEnd[address(this)] = block.timestamp + 31536000;
	}


	function min(uint256 a, uint256 b) internal pure returns (uint256) {
		return a < b ? a : b;
	}

	function updateRewardOnMint(address _user, uint256 _amount) external isValidAddress isContract {
        address _contract = msg.sender;
        uint256 _rewardTime = rewardsEnd[_contract];

		uint256 _time = min(block.timestamp, _rewardTime);
        
		uint256 timerUser = lastUpdates[_contract][_user];
		if (timerUser > 0)
			rewards[_contract][_user] = rewards[_contract][_user].add(ILions(_contract).balanceOG(_user).mul(BASE_RATE.mul((_time.sub(timerUser)))).div(REWARD_SEPARATOR)
				.add(_amount.mul(INITIAL_ISSUANCE)));
		else 
			rewards[_contract][_user] = rewards[_contract][_user].add(_amount.mul(INITIAL_ISSUANCE));
		
        lastUpdates[_contract][_user] = block.timestamp;
	}

	// called on transfers
	function updateReward(address _from, address _to) external isValidAddress isContract{
        address _contract = msg.sender;
        uint256 _rewardTime = rewardsEnd[_contract];

        uint256 _time = min(block.timestamp, _rewardTime);
        uint256 timerFrom = lastUpdates[_contract][_from];
            if (timerFrom > 0)
                rewards[_contract][_from] += ILions(_contract).balanceOG(_from).mul(BASE_RATE.mul((_time.sub(timerFrom)))).div(REWARD_SEPARATOR);
            if (timerFrom != _rewardTime)
                lastUpdates[_contract][_from] = _time;
            if (_to != address(0)) {
                uint256 timerTo = lastUpdates[_contract][_to];
                if (timerTo > 0)
                    rewards[_contract][_to] += ILions(_contract).balanceOG(_to).mul(BASE_RATE.mul((_time.sub(timerTo)))).div(REWARD_SEPARATOR);
                if (timerTo != _rewardTime)
                    lastUpdates[_contract][_to] = _time;
        }
    }


	function getReward(address _to) external isValidAddress isContract {
		uint256 reward = rewards[msg.sender][_to];
		if (reward > 0) {
			rewards[msg.sender][_to] = 0;
			_mint(_to, reward);
			emit RewardPaid(_to, reward);
		}
	}

	function burn(address _from, uint256 _amount) external {
		_burn(_from, _amount);
	}

	function getTotalClaimable(address _user) external view isValidAddress isContract returns(uint256) {
        address _contract = msg.sender;
        uint256 _rewardTime = rewardsEnd[_contract];

		uint256 time = min(block.timestamp, _rewardTime);
		uint256 pending = ILions(msg.sender).balanceOG(_user).mul(BASE_RATE.mul((time.sub(lastUpdates[_contract][_user])))).div(REWARD_SEPARATOR);
		return rewards[_contract][_user] + pending;
	}

    function addContract(address _contract, uint256 _rewardTime) public onlyOwner isContract {
        contracts.push(_contract);
        rewardsEnd[_contract] = _rewardTime;
    }
}