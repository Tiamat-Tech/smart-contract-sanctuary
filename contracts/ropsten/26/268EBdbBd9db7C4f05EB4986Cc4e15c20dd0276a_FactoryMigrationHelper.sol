//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;



import "./IERC20.sol";
import "./SafeMath.sol";

contract FactoryMigrationHelper {

	uint256 public normalMigrationFee = 0;
	address public owner;

	modifier onlyOwner(){
		require(msg.sender == owner, "You are not the owner");
		_;
	}

	event RescueBNB(address indexed account, uint256 amount);

	event NewMigration(address indexed address_);

	event TokenDeposited(address indexed address_, uint256 amount);

	address[] public migrations;

	constructor()  {
		owner = msg.sender;
	}

	function setMigrationFee(uint256 _normalMigrationFee) public onlyOwner {
		normalMigrationFee = _normalMigrationFee;
	}

	// Claim BNB from the contract
	function rescueBNB() external onlyOwner {
		uint256 balance = address(this).balance;
		payable(msg.sender).transfer(address(this).balance);
		emit RescueBNB(msg.sender, balance);
	}


	function createNewMigration(string memory title, IERC20 oldTokenAddress, IERC20 newTokenAddress, 
		uint256 decimalsOldToken, uint256 decimalsNewToken, uint256 divider) public payable {
		require(msg.value > normalMigrationFee, "You need to pay the fee to start the migration!");
		address newMigration = address(new MigrationHelper(address(this), title, oldTokenAddress, newTokenAddress,
		decimalsOldToken, decimalsNewToken, divider));
		migrations.push(newMigration);

		emit NewMigration(newMigration);
	}

	function getMigrations() public view returns (address[] memory) {
		return migrations;
	}

	function sendTokenToContract(uint256 amount, uint256 migrationId) public onlyOwner{
    require(migrations.length > migrationId, "Migration id is out of index!");
		MigrationHelper hc = MigrationHelper(migrations[migrationId]);
		hc.sendNewTokensToContract(amount);
		emit TokenDeposited(msg.sender, amount);
	}

	function claimToken(uint256 migrationId) public {
    require(migrations.length > migrationId, "Migration id is out of index!");
		MigrationHelper hc = MigrationHelper(migrations[migrationId]);
		hc.claim();
	}
}

contract MigrationHelper {

	using SafeMath for uint256;

	address owner;
	string title;
	IERC20 oldTokenAddress;
	IERC20 newTokenAddress;

	uint256 decimalsOldToken;
	uint256 decimalsNewToken;

	uint256 operationalDecimals = 18;

	uint256 divider;
	// uint256 tokensForDistribution;

	uint256 newAmountToReceive;
	uint256 oldAmount;

	mapping(address => uint256) received;

	event Claim(address indexed address_, uint256 amount);

	constructor(
    address _owner,
    string memory  _title,
    IERC20 _oldTokenAddress,
    IERC20 _newTokenAddress,
	  uint256 _decimalsOldToken,
    uint256 _decimalsNewToken,
    uint256 _divider
    // uint256 _tokensForDistribution
  ) {
		owner = _owner;
		title = _title;
		oldTokenAddress = _oldTokenAddress;
		newTokenAddress = _newTokenAddress;
		decimalsOldToken = _decimalsOldToken;
		decimalsNewToken = _decimalsNewToken;
		divider = _divider;
		// tokensForDistribution = _tokensForDistribution.div(10**decimalsNewToken).mul(10**operationalDecimals);
	}

	modifier onlyOwner(){
		require(msg.sender == owner, "You are not the owner");
		_;
	}
	
	function sendNewTokensToContract(uint256 _amount) public onlyOwner(){
		// Allow the contract
		newTokenAddress.approve(address(this), _amount.div(10**decimalsNewToken).mul(10**operationalDecimals));

		// Transfer the tokens from msg.sender to the contract
		newTokenAddress.transferFrom(msg.sender, address(this), _amount.div(10**decimalsNewToken).mul(10**operationalDecimals));
	}

	function claim() public {
		require(received[msg.sender] == 0, "You already received your tokens");
    require(oldTokenAddress.balanceOf(msg.sender) > 0, "You don't have old token");
    uint256 amountToReceive = newAmountToReceive.div(10**decimalsNewToken).mul(10**operationalDecimals);

    setNewAmountToReceive(msg.sender);
    newTokenAddress.approve(address(this), amountToReceive);
    newTokenAddress.transferFrom(address(this), msg.sender, newAmountToReceive);

    received[msg.sender] = amountToReceive;

    emit Claim(msg.sender, amountToReceive);
	}

	function setNewAmountToReceive(address _receiver) private {
		newAmountToReceive = oldTokenAddress.balanceOf(_receiver).div(10**decimalsOldToken).mul(10**decimalsNewToken).div(divider);
	}
}