// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

// Learn more about the ERC20 implementation 
// on OpenZeppelin docs: https://docs.openzeppelin.com/contracts/4.x/erc20
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IKongz {
	function balanceOG(address _user) external view returns(uint256);
}

contract BAMBOOToken is ERC20 {
    using SafeMath for uint256;

    uint256 constant public BASE_RATE = 10 ether; 
	uint256 constant public INITIAL_ISSUANCE = 300 ether;
	// Tue Mar 18 2031 17:46:47 GMT+0000
	uint256 constant public END = 1931622407;

	mapping(address => uint256) public rewards;
	mapping(address => uint256) public lastUpdate;

	IKongz public  kongzContract;

	event RewardPaid(address indexed user, uint256 reward);

    constructor(address _kongz) ERC20("BAMBOO", "BAB") {
        _mint(msg.sender, 146043480 * 10 ** 18);
        kongzContract = IKongz(_kongz);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
		return a < b ? a : b;
	}

	// called when minting many NFTs
	// updated_amount = (balanceOG(user) * base_rate * delta / 86400) + amount * initial rate
	function updateRewardOnMint(address _user, uint256 _amount) external {
		require(msg.sender == address(kongzContract), "Can't call this");
		uint256 time = min(block.timestamp, END);
		uint256 timerUser = lastUpdate[_user];
		if (timerUser > 0)
			rewards[_user] = rewards[_user].add(kongzContract.balanceOG(_user).mul(BASE_RATE.mul((time.sub(timerUser)))).div(86400).add(_amount.mul(INITIAL_ISSUANCE)));
		else 
			rewards[_user] = rewards[_user].add(_amount.mul(INITIAL_ISSUANCE));
		lastUpdate[_user] = time;
	}

	// called on transfers
	function updateReward(address _from, address _to, uint256 _tokenId) external {
		require(msg.sender == address(kongzContract));
		if (_tokenId < 1001) {
			uint256 time = min(block.timestamp, END);
			uint256 timerFrom = lastUpdate[_from];
			if (timerFrom > 0)
				rewards[_from] += kongzContract.balanceOG(_from).mul(BASE_RATE.mul((time.sub(timerFrom)))).div(86400);
			if (timerFrom != END)
				lastUpdate[_from] = time;
			if (_to != address(0)) {
				uint256 timerTo = lastUpdate[_to];
				if (timerTo > 0)
					rewards[_to] += kongzContract.balanceOG(_to).mul(BASE_RATE.mul((time.sub(timerTo)))).div(86400);
				if (timerTo != END)
					lastUpdate[_to] = time;
			}
		}
	}

	function getReward(address _to) external {
		require(msg.sender == address(kongzContract));
		uint256 reward = rewards[_to];
		if (reward > 0) {
			rewards[_to] = 0;
			_mint(_to, reward);
			emit RewardPaid(_to, reward);
		}
	}

	function burn(address _from, uint256 _amount) external {
		require(msg.sender == address(kongzContract));
		_burn(_from, _amount);
	}

	function getTotalClaimable(address _user) external view returns(uint256) {
		uint256 time = min(block.timestamp, END);
		uint256 pending = kongzContract.balanceOG(_user).mul(BASE_RATE.mul((time.sub(lastUpdate[_user])))).div(86400);
		return rewards[_user] + pending;
	}
}