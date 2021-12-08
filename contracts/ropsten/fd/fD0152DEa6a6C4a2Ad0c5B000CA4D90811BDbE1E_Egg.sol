import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

interface IEgg is IERC20 {
  function mint(address, uint256) external;
}

library SafeMath {
   
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, 'SafeMath: addition overflow');

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, 'SafeMath: subtraction overflow');
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, 'SafeMath: multiplication overflow');

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, 'SafeMath: division by zero');
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        
        return c;
    }
    
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, 'SafeMath: modulo by zero');
    }
    
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Ownable is Context {
    address private _owner;
  address private newOwner;

  event OwnershipTransferred(address indexed _from, address indexed _to);

  constructor() {
    _owner = msg.sender;
  }

  modifier onlyOwner {
    require(msg.sender == _owner);
    _;
  }

  function transferOwnership(address _newOwner) public onlyOwner {
    newOwner = _newOwner;
  }
  function acceptOwnership() public {
    require(msg.sender == newOwner);
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
    newOwner = address(0);
  }

    
}



//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract Egg is ERC20, IEgg, Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  address private _owner;  
  
  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowances;
  
  uint256 private _totalSupply;

  
  constructor(address __ants) ERC20('EGG', 'EGG') {
    _owner = __ants;
    _totalSupply = 100;
    _balances[msg.sender] = _totalSupply;
    emit Transfer(address(0), msg.sender, _totalSupply);
  }

  function mint(address _to, uint256 _amount) external override {
    //solhint-disable-next-line
    require(msg.sender == _owner, 'Only the ants contract can call this function, please refer to the ants contract');
    _mint(_to, _amount);
  }  

  function decimals() public view virtual override returns (uint8) {
    return 18;
  }
}