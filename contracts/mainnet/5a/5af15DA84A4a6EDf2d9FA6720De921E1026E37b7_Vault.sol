pragma solidity ^0.5.17;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol';
import '@openzeppelin/contracts/ownership/Ownable.sol';


interface IController {
  function withdraw(address, uint256) external;

  function balanceOf(address) external view returns (uint256);

  function earn(address, uint256) external;

  function want(address) external view returns (address);

  function rewards() external view returns (address);

  function vaults(address) external view returns (address);

  function strategies(address) external view returns (address);
}

contract Vault is ERC20, ERC20Detailed {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  IERC20 public token;

  uint256 public min = 9500;
  uint256 public constant max = 10000;

  address public governance;
  address public controller;

  constructor(
    address _token,
    address _controller,
    address _governance
  )
    public
    ERC20Detailed(
      string(abi.encodePacked('Stake DAO ', ERC20Detailed(_token).name())),
      string(abi.encodePacked('sd', ERC20Detailed(_token).symbol())),
      ERC20Detailed(_token).decimals()
    )
  {
    token = IERC20(_token);
    controller = _controller;
    governance = _governance;
  }

  function balance() public view returns (uint256) {
    return
      token.balanceOf(address(this)).add(
        IController(controller).balanceOf(address(token))
      );
  }

  function setMin(uint256 _min) external {
    require(msg.sender == governance, '!governance');
    min = _min;
  }

  function setGovernance(address _governance) public {
    require(msg.sender == governance, '!governance');
    governance = _governance;
  }

  function setController(address _controller) public {
    require(msg.sender == governance, '!governance');
    controller = _controller;
  }

  // Custom logic in here for how much the vault allows to be borrowed
  // Sets minimum required on-hand to keep small withdrawals cheap
  function available() public view returns (uint256) {
    return token.balanceOf(address(this)).mul(min).div(max);
  }

  function earn() public {
    uint256 _bal = available();
    token.safeTransfer(controller, _bal);
    IController(controller).earn(address(token), _bal);
  }

  function depositAll() external {
    deposit(token.balanceOf(msg.sender));
  }

  function deposit(uint256 _amount) public {
    uint256 _pool = balance();
    uint256 _before = token.balanceOf(address(this));
    token.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 _after = token.balanceOf(address(this));
    _amount = _after.sub(_before); // Additional check for deflationary tokens
    uint256 shares = 0;
    if (totalSupply() == 0) {
      shares = _amount;
    } else {
      shares = (_amount.mul(totalSupply())).div(_pool);
    }
    _mint(msg.sender, shares);
  }

  function withdrawAll() external {
    withdraw(balanceOf(msg.sender));
  }

  // Used to swap any borrowed reserve over the debt limit to liquidate to 'token'
  function harvest(address reserve, uint256 amount) external {
    require(msg.sender == controller, '!controller');
    require(reserve != address(token), 'token');
    IERC20(reserve).safeTransfer(controller, amount);
  }

  // No rebalance implementation for lower fees and faster swaps
  function withdraw(uint256 _shares) public {
    uint256 r = (balance().mul(_shares)).div(totalSupply());
    _burn(msg.sender, _shares);

    uint256 b = token.balanceOf(address(this));
    if (b < r) {
      uint256 _withdraw = r.sub(b);
      IController(controller).withdraw(address(token), _withdraw);
      uint256 _after = token.balanceOf(address(this));
      uint256 _diff = _after.sub(b);
      if (_diff < _withdraw) {
        r = b.add(_diff);
      }
    }
    token.safeTransfer(msg.sender, r);
  }

  function getPricePerFullShare() public view returns (uint256) {
    return totalSupply() == 0 ? 1e18 : balance().mul(1e18).div(totalSupply());
  }
}