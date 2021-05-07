// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

import "./KEKCoin.sol";
import "./DateTime.sol";

contract Bank {
    using BokkyPooBahsDateTimeLibrary for uint256;
    using SafeMath for uint256;

  	struct DepositProgram {
        uint8 id;
  		bool isActive;
        uint16 compoundings;
        uint16 interestRate; //2 decimals 625 => 6.25%
        uint16 minPeriod; //period in months
    }

    struct Deposit {
        uint startAmount;
        uint depositStartDate;
        uint minEndDate;
    }

    struct CreditProgram {
        uint8 id;
        bool isActive;
        uint interestRateYear; //2 decimals 625 => 6.25%
        uint interestRateMonth; //18 decimals, (1+r)^(1/12) (calculating this value in solidity is extremely costly)
        uint minAmount;
        uint maxAmount;
    }
    
    struct Credit {
        uint amount;
        uint8 creditProgram;
        uint creditStartDate;
        uint period;
        bool isActive;
    }

    address public owner = msg.sender;

	KEKCoin public kekCoin;

	mapping (uint8 => DepositProgram) private depositPrograms;
    mapping (uint8 => CreditProgram) private creditPrograms;

	mapping (bytes32 => Deposit) private deposits;
	mapping (bytes32 => bool) private activeDepositProgramsForUser;

    mapping (address => Credit) private credits; 
    mapping (address => bool) private creditApprovals;

	event DepositEvent(address indexed user, uint amount, uint timeStart, uint minEndDate);
    event Withdraw(address indexed user, uint amount, uint8 depositProgram, uint withdrawDate);
    event CreditRequest(address indexed user, uint amount, uint8 creditProgram, uint requestDate);
    event CreditApproved(address indexed user, bool answer, uint approvementDate);
    event CreditEvent(address indexed user, uint creditDate);
    event PayOff(address indexed user, uint amount);

	constructor(KEKCoin _kekCoin) {
		kekCoin = _kekCoin;
		loadPrograms();
	}

    modifier onlyOwner() { 
        require (msg.sender == owner); 
        _; 
    }


    fallback () external payable {
        buyTokens(msg.sender);
    } 

    function buyTokens(address _beneficiary) public payable {
        uint rate = 1;

        kekCoin.mint(_beneficiary, msg.value.mul(rate));

    }

	function getDepositProgram(uint8 _program) public view returns (DepositProgram memory){
		return depositPrograms[_program];
	}

	function getDepositBalance(uint8 _program) public view returns (uint){
		bytes32 key = keccak256(abi.encodePacked(msg.sender, _program));
		return deposits[key].startAmount;
	}

    function getApproval() public view returns(bool approval){
        approval = creditApprovals[msg.sender];
    }
    
    function addDepositProgram(
    	uint8 _id, 
    	bool _isActive,
    	uint16 _compoundings,
    	uint16 _interestRate, 
    	uint16 _minPeriod
    ) 
    	public 
        onlyOwner
    {
    	DepositProgram memory depositProgram = DepositProgram(_id, _isActive, _compoundings, _interestRate, _minPeriod);
    	depositPrograms[_id] = depositProgram;
  	}

    function addCreditProgram(
        uint8 _id,
        bool _isActive,
        uint _interestRateYear,
        uint _interestRateMonth, 
        uint _minAmount,
        uint _maxAmount
    ) 
        public 
        onlyOwner
    {
        CreditProgram memory creditProgram = CreditProgram(_id, _isActive, _interestRateYear, _interestRateMonth, _minAmount, _maxAmount);
        creditPrograms[_id] = creditProgram;
    }

  	function deposit(uint _amount, uint8 _program) public {
  		kekCoin.transferFrom(msg.sender, address(this), _amount);

  		bytes32 key = keccak256(abi.encodePacked(msg.sender, _program));

        require(depositPrograms[_program].id != 0, "Requested DepositProgram doesn't exist");
        require(depositPrograms[_program].isActive, "Requested DepositProgram isn't active");
        require(_amount > 0, "Deposit amount should be above 0");
  		require(activeDepositProgramsForUser[key] == false, "Error, You can't make a deposit, if you already have a one");

        uint minPeriod = depositPrograms[_program].minPeriod;
  		activeDepositProgramsForUser[key] = true;
  		deposits[key] = Deposit(_amount, block.timestamp, BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp, minPeriod));
  		emit DepositEvent(msg.sender, _amount, block.timestamp,BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp, minPeriod));
  	}


  	function withdraw(uint8 _program) public {
  		bytes32 key = keccak256(abi.encodePacked(msg.sender, _program));
  		require(activeDepositProgramsForUser[key] == true, "Error, You must have active deposit to withdraw");

 		DepositProgram storage depositProgram = depositPrograms[_program];
 		Deposit storage dep = deposits[key];

        if (block.timestamp < dep.minEndDate){
            activeDepositProgramsForUser[key] = false;
            kekCoin.transfer(msg.sender, dep.startAmount);
            emit Withdraw(msg.sender, dep.startAmount, _program, block.timestamp);
            return;
        }

 		uint8 shift = 5;
 		//shifting decimal point to increase accuracy of calculating
 		uint r = depositProgram.interestRate;
 		uint n = depositProgram.compoundings;

 		uint ny = (n*(block.timestamp - dep.depositStartDate)/(24*60*60*365));

 		uint amount = dep.startAmount*10**shift;

        // X = D(1 + r/n)^n*y

 		for (uint i = 0;i < ny; i++){
 			amount = (amount * (n*10000 + r)) / (n*10000);
 		}

 		amount = amount/10**shift;

        activeDepositProgramsForUser[key] = false;
 		kekCoin.transfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount, _program, block.timestamp);
  	}

    function createCreditRequest(uint _amount, uint8 _creditProgram, uint _period) public {

        CreditProgram memory program = creditPrograms[_creditProgram];
        require (program.id != 0, "Credit program doesn't exist!!!");
        require (_amount >= program.minAmount && _amount <= program.maxAmount, "amount is unacceptable for requested program");
        require (credits[msg.sender].isActive == false, "You already have a credit");

        creditApprovals[msg.sender] = false;
        credits[msg.sender] = Credit(_amount, _creditProgram,block.timestamp,_period,false);
        emit CreditRequest(msg.sender, _amount, _creditProgram, block.timestamp);
    }

    function approveCreditRequest(address user, bool answer) public onlyOwner {
        creditApprovals[user] = answer;
        emit CreditApproved(user, answer, block.timestamp);
    }

    function takeCredit() public {
        require (creditApprovals[msg.sender] == true, "You should get credit approval firstly");

        Credit storage credit = credits[msg.sender];

        credit.isActive = true;
        credit.creditStartDate = block.timestamp;
        kekCoin.transfer(msg.sender, credit.amount);

        emit CreditEvent(msg.sender, block.timestamp);
    }

    function payOff() public {
        Credit storage credit = credits[msg.sender]; 
        require(credit.isActive, "Your credit already payed off");

        credit.isActive = false;

        uint shift = 10**5;

        CreditProgram memory program = creditPrograms[credit.creditProgram];

        uint amount = credit.amount*shift;
        uint months = credit.creditStartDate.diffMonths(block.timestamp);

        for (uint i = 0; i < months/12; i++) {
            amount = (amount * (10000 + program.interestRateYear)) / 10000;
        }
        amount = amount;

        uint n = months % 12;

        for (uint i = 0; i < n; i++){
            amount = (amount * program.interestRateMonth) / 10**18;
        }
        // return (months,(uint(months) + uint(credit.period)));
        emit PayOff(msg.sender, kekCoin.balanceOf(msg.sender));
        //take into acccount whether payment has been delayed, if so, fine 10% from sum of credit
        if (months >= credit.period + 1) {
            amount = amount + credit.amount *shift/10;
        }
        emit PayOff(msg.sender, amount);

        // return (months, credit.period);

        amount = amount/shift; 

        require (kekCoin.balanceOf(msg.sender) + 1 > amount, "Not enough KEKcoins to pay off");
        
        kekCoin.transferFrom(msg.sender, address(this), amount);
    }

  	function loadPrograms() private {
  		depositPrograms[1] =  DepositProgram(1, true, 12, 5*10**2, 0);
  		depositPrograms[2] = DepositProgram(2, true, 12, 8*10**2, 12);

        creditPrograms[1] =  CreditProgram(1, true, 6*10**2, 1004867550565343104, 100, 100000000000);
        creditPrograms[2] = CreditProgram(2, true, 8*10**2, 1006434030110003456, 100, 100000000000);
  	}
  	
    // function twelfthRoot(uint x, uint precision) public view returns (uint) {
    //     x = x * (precision**12);
    //     if (x < 2)       
    //         return (x);
     
    //     uint result;
     
    //     uint start = 1;
    //     uint end = x * precision / 2;
    //     uint mid;uint sqr;

    //     while (start <= end){
     
    //         mid = (start + end) / 2;
    //         sqr = fastPow(mid, 12 , x);
     
    //         if (sqr == x)
    //             return mid;     
    //         else if (sqr < x) {
    //             start = mid + 1;
    //             result = mid;
    //         }
    //         else
    //             end = mid - 1;
    //     }
     
    //     return (result);

    // }

    // function fastPow(uint x, uint y, uint c) public pure returns(uint) {
    //     uint result = x;
        
    //     for(uint i = 1; i < y;i++){
    //                     if (result > c) return result;
    //                     if (c / result < x) return c+1;
    //         result *=x;
    //     }

    //     return result;
    // }
}