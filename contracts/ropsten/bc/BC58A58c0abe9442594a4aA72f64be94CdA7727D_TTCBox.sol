// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol"; 

// import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol"; 
// import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol"; 
// import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol"; 


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
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
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
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }


    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }


    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract TTCBox {

    using SafeMathUpgradeable for uint;
    using AddressUpgradeable for address;

    address public admin;
    address public teamAddr;
    IERC20 public USDT;
    IERC20 public WOD;

    uint public poolRate;
    uint public teamRate;
    uint public userRate;
    uint public team2Rate;
    bool initialized;
    mapping(address => uint) public deposits;

    event WithdrawUSDT(address, uint);
    event WithdrawWOD(address, uint);
    event Deposit(address, uint);
    event Burn(address, uint);

    modifier onlyAdmin {
        require(msg.sender == admin,"You Are not admin");
        _;
    }

    function initialize(address _admin, address _teamAddr, address _usdtAddr, address _wodAddr) external {
        require(!initialized,"initialized");
        admin = _admin;
        teamAddr = _teamAddr;
        USDT = IERC20(_usdtAddr);
        WOD = IERC20(_wodAddr);
        poolRate = 90;
        teamRate = 10;
        userRate = 97;
        team2Rate = 3;
        initialized = true;
    }

    function setParam(
        address _admin,
        address _teamAddr,
        uint _poolRate,
        uint _teamRate,
        uint _userRate,
        uint _team2Rate
        ) external onlyAdmin {
        admin = address(_admin);
        teamAddr = address(_teamAddr);
        poolRate = _poolRate;
        teamRate = _teamRate;
        userRate = _userRate;
        team2Rate = _team2Rate;
    }

    function deposit(uint _amount) external {        
        USDT.transferFrom(msg.sender, address(this), _amount.mul(poolRate).div(100));
        USDT.transferFrom(msg.sender, teamAddr, _amount.mul(teamRate).div(100));
        deposits[msg.sender] += _amount;
        emit Deposit(msg.sender, _amount);
    }

    function withdrawUSDTFromPool(address _userAddr, uint _amount) external onlyAdmin {
        require(_userAddr!=address(0),"Can not withdraw to Blackhole");
        USDT.transfer(_userAddr, _amount.mul(userRate).div(100));
        USDT.transfer(teamAddr, _amount.mul(team2Rate).div(100));

        emit WithdrawUSDT(_userAddr, _amount.mul(userRate));
    }

    function batchAdminWithdrawUSDT(address[] memory _userList, uint[] memory _amount) external onlyAdmin {
        for (uint i = 0; i < _userList.length; i++) {
            USDT.transfer(address(_userList[i]), uint(_amount[i]));
        }
    }

    function adminWithdrawUSDT(uint _amount) external onlyAdmin {
        USDT.transfer(admin, _amount);
    }

    function withdrawWOD(address _addr, uint _amount) external onlyAdmin {
        require(_addr!=address(0),"Can not withdraw to Blackhole");
        WOD.transfer(_addr, _amount);
    }

    function batchAdminWithdrawWOD(address[] memory _userList, uint[] memory _amount) external onlyAdmin {
        for (uint i = 0; i < _userList.length; i++) {
            WOD.transfer(address(_userList[i]), uint(_amount[i]));
        }
    }

    function burnWOD(uint _amount) external onlyAdmin {
        WOD.transferFrom(msg.sender,address(0x000000000000000000000000000000000000dEaD), _amount);

        emit Burn(msg.sender, _amount);
    }

    receive () external payable {}


}