// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SushiBar is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // Address token
    IERC20 public token;
    // entrance fee
    uint256 public entranceFeeFactor;
    // 100 = 1%
    uint256 constant entranceFeeFactorMax = 10000;
    // 4% is the max entrance fee. LL = lowerlimit
    uint256 constant entranceFeeFactorLL = 9600;
    // withdraw fee
    uint256 public withdrawFeeFactor;
    // 100 = 1%
    uint256 public constant withdrawFeeFactorMax = 10000;
    // 1% is the max withdraw fee. LL = lowerlimit
    uint256 public constant withdrawFeeFactorLL = 9900;
    // Dev address
    address public devAddress;
    // Reserves address
    address public reservesAddress;
    
    constructor(string memory _name, string memory _alias, IERC20 _token, uint256 _entranceFeeFactor, uint256 _withdrawFeeFactor, address _dev, address _reserves) ERC20(_name, _alias) public {
        require(_entranceFeeFactor >= entranceFeeFactorLL, "!safe - too low");
        require(_entranceFeeFactor <= entranceFeeFactorMax, "!safe - too high");
        require(_withdrawFeeFactor >= withdrawFeeFactorLL, "!safe - too low");
        require(_withdrawFeeFactor <= withdrawFeeFactorMax, "!safe - too high");
        token = _token;
        entranceFeeFactor = _entranceFeeFactor;
        withdrawFeeFactor = _withdrawFeeFactor;
        devAddress = _dev;
        reservesAddress = _reserves;
    }

    // Enter the lair. Pay some Token. Earn some Lair.
    function enter(uint256 _tokenAmount) external nonReentrant {
        uint256 totalToken = token.balanceOf(address(this));
        uint256 totalLair = totalSupply();
        uint256 _tokenAmountSender = _tokenAmount.mul(entranceFeeFactor).div(entranceFeeFactorMax);
        uint256 _tokenAmountFee = _tokenAmount.sub(_tokenAmountSender);
        if (totalLair == 0) {
            _mint(msg.sender, _tokenAmount);
        } else {
            uint256 lairAmount = _tokenAmountSender.mul(totalLair).div(totalToken);
            _mint(msg.sender, lairAmount);
        }
        token.transferFrom(msg.sender, address(this), _tokenAmount);
        if(_tokenAmountFee > 0 && totalLair > 0){
            token.transfer(devAddress, _tokenAmountFee.div(4));
            token.transfer(reservesAddress, _tokenAmountFee.div(4));
        }
    }

    // Leave the lair. Claim back your Token.
    function leave(uint256 _lairAmount) external nonReentrant {
        uint256 totalLair = totalSupply();
        uint256 tokenAmount = _lairAmount.mul(token.balanceOf(address(this))).div(totalLair);
        _burn(msg.sender, _lairAmount);
        tokenAmount = tokenAmount.mul(withdrawFeeFactor).div(withdrawFeeFactorMax);
        token.transfer(msg.sender, tokenAmount);
    }

    // Burn lairs
    function burn(uint256 _lairAmount) external nonReentrant {
        _burn(msg.sender, _lairAmount);
    }

    // returns the total amount of Tokens an address has in the contract including fees earned
    function TokenBalance(address _account) external view returns (uint256 tokenAmount_) {
        uint256 lairAmount = balanceOf(_account);
        uint256 totalLair = totalSupply();
        tokenAmount_ = lairAmount.mul(token.balanceOf(address(this))).div(totalLair);
    }

    //returns how much Tokens someone gets for depositing lair
    function LairForToken(uint256 _lairAmount) external view returns (uint256 tokenAmount_) {
        uint256 totalLair = totalSupply();
        tokenAmount_ = _lairAmount.mul(token.balanceOf(address(this))).div(totalLair);
    }

    //returns how much Lair someone gets for depositing Token
    function TokenForLair(uint256 _tokenAmount) public view returns (uint256 lairAmount_) {
        uint256 totalToken = token.balanceOf(address(this));
        uint256 totalLair = totalSupply();
        if (totalLair == 0 || totalToken == 0) {
            lairAmount_ = _tokenAmount;
        }
        else {
            lairAmount_ = _tokenAmount.mul(totalLair).div(totalToken);
        }
    }

    // Entrance fee allocation
    function setEntranceFeeFactor(uint256 _entranceFeeFactor) public onlyOwner {
        require(_entranceFeeFactor >= entranceFeeFactorLL, "!safe - too low");
        require(_entranceFeeFactor <= entranceFeeFactorMax, "!safe - too high");
        entranceFeeFactor = _entranceFeeFactor;
    }

    // Withdraw fee allocation
    function setWithdrawFeeFactor(uint256 _withdrawFeeFactor) public onlyOwner {
        require(_withdrawFeeFactor >= withdrawFeeFactorLL, "!safe - too low");
        require(_withdrawFeeFactor <= withdrawFeeFactorMax, "!safe - too high");
        withdrawFeeFactor = _withdrawFeeFactor;
    }

}