// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract TokenScrow {
  using SafeMath for uint;
  IERC20 public token;

  constructor(address tokenAddr) {
    token = IERC20(tokenAddr);
  }

  event Deposited(address indexed payee, uint256 weiAmount);
  event Withdrawn(address indexed payee, uint256 weiAmount);

  mapping(address => uint256) private _deposits;

  function depositsOf(address payee) public view returns (uint256) {
    return _deposits[payee];
  }

  /**
    * @dev Stores the sent _amount as credit to be withdrawn.
    * @param _amount The amount funds to deposit.
    */
  function deposit(uint256 _amount) public {
    address msgSender = address(msg.sender);
    token.transferFrom(msgSender, address(this), _amount);
    _deposits[msgSender] = _deposits[msgSender].add(_amount);
    emit Deposited(msgSender, _amount);
  }

  /**
    * @dev Withdraw accumulated balance for a payee, forwarding all gas to the
    * recipient.
    *
    * WARNING: Forwarding all gas opens the door to reentrancy vulnerabilities.
    * Make sure you trust the recipient, or are either following the
    * checks-effects-interactions pattern or using {ReentrancyGuard}.
    *
    * @param _amount The address whose funds will be withdrawn and transferred to.
    */
  function withdraw(uint256 _amount) public {
    address msgSender = address(msg.sender);
    require(_deposits[msgSender] >= _amount, "withdraw: not good");
    
    if(_amount > 0) {
      token.transferFrom(address(this), msgSender, _amount);
      _deposits[msgSender] = _deposits[msgSender].sub(_amount);
      emit Withdrawn(msg.sender, _amount);
    }

  }

  function withdrawAll() public {
    address msgSender = address(msg.sender);
    uint256 amount = _deposits[msgSender];
    require(_deposits[msgSender] > 0, "withdraw: not good");
    
    token.transferFrom(address(this), msgSender, amount);
    emit Withdrawn(msgSender, amount);
    _deposits[msgSender] = 0;
  }
}