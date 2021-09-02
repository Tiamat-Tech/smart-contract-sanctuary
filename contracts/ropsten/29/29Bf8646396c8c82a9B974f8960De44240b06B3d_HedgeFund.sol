// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./Libs/SafeMath.sol";
import "./Libs/Ownable.sol";

contract HedgeFund is Ownable {

    using SafeMath for uint256;

    mapping (address => bool) public isDepositor;

    mapping (address => uint256) public amountDeposit;
    mapping (address => uint256) public amountDepositorEarned;

    mapping(uint256 => uint256) public levelPrice;
    mapping (address => uint256) public levelOfDepositor;
    uint256 public constant LAST_LEVEL = 12;

    mapping (address => bool) public hasSponsor;
    mapping (address => address) public sponsorOfDepositor;
    mapping (address => uint256) public feeFromRecruiters;
    mapping (address => uint256) public depositTime;

    uint256 public lastTimestampEthSentToInstitution;

    uint256 public lastTimestampProfitReceived;

    address public manager;

    address payable public institutionWallet;

    uint256 public totalEthDeposited;

    uint256 public currentEthDeposited;

    uint256 public totalEthSentToInstitution;

    uint256 public totalEthPendingSubscription;
    uint256 public totalEthPendingWithdrawal;
    uint256 public totalSharesPendingRedemption;

    // event ProcessedDividendTracker(
    //     uint256 iterations,
    //     uint256 claims,
    //     uint256 lastProcessedIndex,
    //     bool indexed automatic,
    //     uint256 gas,
    //     address indexed processor
    // );
    bool private unlocked = true;
    modifier lock() {
        require(unlocked == true, 'TotemSwap: LOCKED');
        unlocked = false;
        _;
        unlocked = true;
    }

    event Deposit(address depositer, uint256 amount, uint256 timestamp);

    modifier onlyManager() {
        require(manager == _msgSender(), "Ownable: caller is not the manager");
        _;
    }

    constructor() public{
        manager = _msgSender();
        levelPrice[1] = 0.025 ether;
        for (uint256 i = 2; i <= LAST_LEVEL; i++) {
            levelPrice[i] = levelPrice[i-1] * 2;
        }
    }

    function setManager(address _manager) external onlyManager() {
        require(_manager != address(0), "Zero address can not be a manager.");
        manager = _manager;
    }

    function setInstitutionWallet(address payable _wallet) external onlyManager() {
        require(_wallet != address(0), "Zero address!");
        institutionWallet = _wallet;
    }

    function deposit(uint256 level) public payable {
        // require(msg.value >= 1 ether,"Amount should be greater than 1 Ether");
        require(msg.value == levelPrice[level], "invalid price");
        require(level > 0 && level <= LAST_LEVEL, "invalid level number");

        totalEthDeposited = totalEthDeposited.add(msg.value);
        currentEthDeposited = currentEthDeposited.add(msg.value);
        
        isDepositor[msg.sender] = true;
        amountDeposit[msg.sender] = amountDeposit[msg.sender].add(msg.value);
        depositTime[msg.sender] = block.timestamp;
        levelOfDepositor[msg.sender] = level;


        emit Deposit(msg.sender, msg.value, block.timestamp);
    }

    function upgradeLevel() public payable {
        require(isDepositor[msg.sender], "Please deposit before upgrading the level.");
        uint256 currentLevel = levelOfDepositor[msg.sender];
        require(currentLevel + 1 <= LAST_LEVEL, "next level invalid");
        require(msg.value == levelPrice[currentLevel + 1], "invalid price");

        totalEthDeposited = totalEthDeposited.add(msg.value);
        currentEthDeposited = currentEthDeposited.add(msg.value);
        amountDeposit[msg.sender] = amountDeposit[msg.sender].add(msg.value);
        depositTime[msg.sender] = block.timestamp;
        levelOfDepositor[msg.sender] = currentLevel + 1;
    }

    function sendFundsToInstitution() public onlyManager() {
        require(currentEthDeposited > 1 ether, "Funds not enought to send to institution.");
        require(address(this).balance >= currentEthDeposited, "Insufficient balance to send to institution.");
        require(institutionWallet != address(0), "No institutional wallet set up.");
        institutionWallet.transfer(currentEthDeposited);
        totalEthSentToInstitution = totalEthSentToInstitution.add(currentEthDeposited);
        currentEthDeposited = 0;
        lastTimestampEthSentToInstitution = block.timestamp;
    }

    function calculateReweard(address account) public view returns (uint256, uint256) {
        require(totalEthSentToInstitution > 0, "No funds have been transferred to the institutional wallet.");
        require(depositTime[account] < lastTimestampEthSentToInstitution && depositTime[account] < lastTimestampProfitReceived, "You don't have profit yet.");
        uint256 profit = totalEthPendingSubscription.mul(amountDeposit[account]).div(totalEthSentToInstitution);
        profit = profit.add(feeFromRecruiters[account]);
        
        uint256 feeToSponsor;
        if (hasSponsor[account]){
            feeToSponsor = profit.mul(2).div(10);
            profit = profit.sub(feeToSponsor);
            // feeFromRecruiters[sponsor] = feeFromRecruiters[sponsor].add(feeToSponsor);
        }

        if (profit < amountDepositorEarned[account]) {
            return (0, 0);
        }
        else {
            profit = profit.sub(amountDepositorEarned[account]);    
        }
        
        return (profit, feeToSponsor);
    }

    function claim() external lock {
        address claimer = msg.sender;
        require(isDepositor[claimer], "You must deposit first to earn profit.");
        uint256 earnedToDeposit = amountDepositorEarned[claimer].div(amountDeposit[claimer]);
        require(earnedToDeposit < 2, "You already have earned 200% of your deposit. Please upgrade your potfolio.");

        (uint256 profit, uint256 feeToSponsor) = calculateReweard(claimer);

        require(profit > 0, "No profit for your account");

        feeFromRecruiters[claimer] = 0;

        if (feeToSponsor > 0){
            address sponsor = sponsorOfDepositor[claimer];
            feeFromRecruiters[sponsor] = feeFromRecruiters[sponsor].add(feeToSponsor);
        }

        profit = profit.sub(amountDepositorEarned[claimer]);
        (bool success, /* bytes memory data */) = payable(claimer).call{value: profit, gas: 30000}("");
        // bool success = payable(claimer).transfer(profit);
        
        if (success) {
            amountDepositorEarned[claimer] = amountDepositorEarned[claimer].add(profit);
        }


    }

    function withdraw() external onlyManager {
        payable(manager).transfer(address(this).balance);
    }

    receive() external payable {
        totalEthPendingSubscription = msg.value;
        lastTimestampProfitReceived = block.timestamp;
    }
   
}