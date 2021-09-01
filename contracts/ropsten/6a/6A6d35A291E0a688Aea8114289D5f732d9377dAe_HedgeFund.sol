// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./Libs/SafeMath.sol";
import "./Libs/Ownable.sol";

contract HedgeFund is Ownable {

    using SafeMath for uint256;

    mapping (address => bool) private isDepositor;

    mapping (address => uint256) private amountDeposit;
    mapping (address => uint256) private amountDepositorEarned;

    mapping (address => uint256) private levelOfDepositor;

    mapping (address => bool) private hasSponsor;
    mapping (address => address) private sponsorOfDepositor;
    mapping (address => uint256) private feeFromRecruiters;

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

    }

    function setManager(address _manager) external onlyManager() {
        require(_manager != address(0), "Zero address can not be a manager.");
        manager = _manager;
    }

    function setInstitutionWallet(address payable _wallet) external onlyManager() {
        require(_wallet != address(0), "Zero address!");
        institutionWallet = _wallet;
    }

    function deposit() public payable {
        require(msg.value == 1 ether,"Amount should be equal to 1 Ether");
        totalEthDeposited = totalEthDeposited.add(msg.value);
        currentEthDeposited = currentEthDeposited.add(msg.value);
        
        isDepositor[msg.sender] = true;
        amountDeposit[msg.sender] = msg.value;


        emit Deposit(msg.sender, msg.value, block.timestamp);
    }

    function sendFundsToInstitution() public onlyManager() {
        require(currentEthDeposited > 1 ether, "Funds not enought to send to institution.");
        require(address(this).balance >= currentEthDeposited, "Insufficient balance to send to institution.");
        institutionWallet.transfer(currentEthDeposited);
        totalEthSentToInstitution = totalEthSentToInstitution.add(currentEthDeposited);
        currentEthDeposited = 0;
    }

    function claim() external lock {
        address claimer = msg.sender;
        require(isDepositor[claimer], "You must deposit first to earn profit.");
        uint256 earnedToDeposit = amountDepositorEarned[claimer].div(amountDeposit[claimer]);
        require(earnedToDeposit < 2, "You already have earned 200% of your deposit. Please upgrade your potfolio.");
        uint256 pendingEthForSubscription = address(this).balance.sub(currentEthDeposited);

        uint256 profit = pendingEthForSubscription.mul(amountDeposit[claimer]).div(totalEthSentToInstitution);
        profit = profit.add(feeFromRecruiters[claimer]);
        feeFromRecruiters[claimer] = 0;
        uint256 feeToSponsor;

        if (hasSponsor[claimer]){
            address sponsor = sponsorOfDepositor[claimer];
            feeToSponsor = profit.mul(2).div(10);
            profit = profit.sub(feeToSponsor);
            feeFromRecruiters[sponsor] = feeFromRecruiters[sponsor].add(feeToSponsor);
        }

        profit = profit.sub(amountDepositorEarned[claimer]);
        (bool success, /* bytes memory data */) = payable(claimer).call{value: profit, gas: 30000}("");
        // bool success = payable(claimer).transfer(profit);
        
        if (success) {
            amountDepositorEarned[claimer] = amountDepositorEarned[claimer].add(profit);
        }


    }

    receive() external payable {

    }

    // function _setAutomatedMarketMakerPair(address pair, bool value) private {
    // }

    // function setSwapTokensAtAmount(uint256 _amount) public onlyOwner() {
    // }

    // function updateGasForProcessing(uint256 newValue) public onlyOwner {
    // }

    // function dividendTokenBalanceOf(address account) public view returns (uint256) {
    // }

    // function excludeFromDividends(address account) external onlyOwner{
    // }

    // function claim() external {
    // }



    // function getNumberOfDividendTokenHolders() external view returns(uint256) {
    // }

    // function setFeeStructure(address from, address to) internal{
        
    // }

    // function buyTokens(uint256 amount, address to) internal {

    // }


}