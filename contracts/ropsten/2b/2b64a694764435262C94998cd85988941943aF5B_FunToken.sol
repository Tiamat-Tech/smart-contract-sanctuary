// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";




contract FunToken is ERC20, Ownable {

    uint256 decimal = 18;
    uint256 weiValue = (10**decimal);
    uint256 initialSupply = 5000000000 * weiValue; //5 Billion
    uint256 seedRound = ((4 * weiValue) * initialSupply) / (100 * weiValue); //400 Million (4% of initial Supply)
    uint256 firstPresale = ((54 * 100000000000000000) * initialSupply) / (100 * weiValue); //540 Million (5.4% of initial supply)
    uint256 secondPresale = ((5 * weiValue) * initialSupply) / (100 * weiValue); // 500 Million (5% of initial Supply)
    uint256 publicSaleListingPrice = ((6 * 100000000000000000) * initialSupply) / (100 * weiValue); //60 Million (0.6% of initial Supply)
    uint256 team = ((25 * weiValue) * initialSupply) / (100 * weiValue); //2.5 Billion (25% of initial supply)
    uint256 advisors = ((20 * weiValue) * initialSupply) / (100 * weiValue); //2 Billion (20% of Initial Supply)
    uint256 ecoSystemFund = ((20 * weiValue) * initialSupply) / (100 * weiValue); //2 Billion (20% of Initial Supply)
    uint256 liquidity = ((10 * weiValue) * initialSupply) / (100 * weiValue); //1 Billion (20% of Initial Supply)
    uint256 community = ((5 * weiValue) * initialSupply) / (100 * weiValue); //500 Million (5% of Initial Supply)
    uint256 reserve = ((5 * weiValue) * initialSupply) / (100 * weiValue); //500 Million (5% of Initial Supply)
    uint256 public seedAllocated = 0;

    uint256 seedVestingDuration = 365; //days
    uint256 seedWithdrawalDuration = 1 days;

    constructor() public ERC20("Fun Token", "FUNN") {
        _mint(address(this), initialSupply);
        //_transfer(address(this), msg.sender, initialDistrubtionAmount);
    }

    enum AccountStatus {
        unlocked, 
        locked
    }

    mapping(address => uint) public beneficiaryBalance;
    mapping(address => uint) public beneficiaryTotalWithdrawn;
    mapping(address => uint) public beneficiaryMaxWithdrawPerPeriod;
    mapping(address => AccountStatus) public beneficiaryAccountStatus;
    mapping(address => uint) public beneficiaryLastClaimTime;
    mapping(address => bool) public isBeneficiary;


    function addBeneficiary(address payable _beneficiary, uint _totalAllocation) onlyOwner public {
        
        //Ensure that the beneficiary is not yet added
        require(!isBeneficiary[_beneficiary], "This beneficiary has already been added");
        require((seedAllocated + _totalAllocation) < seedRound, "Exceeds total allocation for seed round");

        //Add the beneficiary to the registry
        beneficiaryBalance[_beneficiary] = _totalAllocation;
        beneficiaryMaxWithdrawPerPeriod[_beneficiary] = _totalAllocation / seedVestingDuration;
        beneficiaryAccountStatus[_beneficiary] = AccountStatus.unlocked;
        beneficiaryLastClaimTime[_beneficiary] = block.timestamp - 1 days; //make first withdrawal instant.
        isBeneficiary[_beneficiary] = true;
        seedAllocated += _totalAllocation;
    }


    function lockBeneficiaryWithdrawal(address payable _beneficiary) onlyOwner public {
      beneficiaryAccountStatus[_beneficiary] = AccountStatus.locked;
    }


    function unlockBeneficiaryWithdrawal(address payable _beneficiary) onlyOwner public {
      beneficiaryAccountStatus[_beneficiary] = AccountStatus.unlocked;
    }


    function viewBeneficiary(address payable _beneficiary) public view returns(uint totalAmountLeft, uint totalAmountWithdrawn, AccountStatus accountStatus, bool isABeneficiary, uint amountWithdrawable)
    {
        totalAmountLeft = beneficiaryBalance[_beneficiary];
        totalAmountWithdrawn = beneficiaryTotalWithdrawn[_beneficiary];
        accountStatus = beneficiaryAccountStatus[_beneficiary];
        isABeneficiary = isBeneficiary[_beneficiary];
        
        //Determine how much to send out to the beneficiary
        uint timeDiff = block.timestamp - beneficiaryLastClaimTime[_beneficiary];
        uint daysAfterLastWithrawal = timeDiff / seedWithdrawalDuration;
        amountWithdrawable = daysAfterLastWithrawal * beneficiaryMaxWithdrawPerPeriod[_beneficiary];
        if (amountWithdrawable > beneficiaryBalance[_beneficiary]) amountWithdrawable = beneficiaryBalance[_beneficiary];
    }

    function claimSeedReward() public {
        
        //Ensure tha the user is a beneficiary
        require(isBeneficiary[msg.sender], "This acount holder is not a beneficiary");
        
        //Ensure that the beneficiaries account is not locked
        require(beneficiaryAccountStatus[msg.sender] == AccountStatus.unlocked, "Beneficiary account is Locked");

        //Ensure that the beneficiary has exceeded the vesting period
        uint timeDiff = block.timestamp - beneficiaryLastClaimTime[msg.sender];
        uint daysAfterLastWithrawal = timeDiff / seedWithdrawalDuration;

        //Require that the user has not withdrawn for at atleast one day
        require(daysAfterLastWithrawal > 0, "Vesting period is not yet over");

        //Determine how much to send out to the beneficiary
        uint amount = daysAfterLastWithrawal * beneficiaryMaxWithdrawPerPeriod[msg.sender];

        //Require that the user still has funds allocated to him
        if(amount > beneficiaryBalance[msg.sender]) amount = beneficiaryBalance[msg.sender];
        require(amount > 0, "User does not have enough funds");

        //Send the token to the beneficiary
        beneficiaryBalance[msg.sender] -= amount;
        beneficiaryTotalWithdrawn[msg.sender] += amount;
        beneficiaryLastClaimTime[msg.sender] = block.timestamp;
        _transfer(address(this), msg.sender, amount);
    }



}