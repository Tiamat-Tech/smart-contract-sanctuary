import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import './IEgg.sol';
import './ICryptoAnts.sol';

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract Egg is ERC20, ERC20Permit, ERC20Votes, IEgg {
  address public _ants;
  ICryptoAnts public ants;

  constructor() ERC20('EGG', 'EGG') ERC20Permit('EGG') {}

  // _ants = __ants;
  // }

  function set(address __ants) external {
    _ants = __ants;
    ants = ICryptoAnts(__ants);
  }

  function mint(address _to, uint256 _amount) external override {
    //solhint-disable-next-line
    require(msg.sender == _ants, 'Only the ants contract can call this function, please refer to the ants contract');
    _mint(_to, _amount);
  }

  function burn(address _account, uint256 _amount) external override {
    //solhint-disable-next-line
    require(msg.sender == _ants, 'Only the ants contract can call this function, please refer to the ants contract');
    _burn(_account, _amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return 0;
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override(ERC20, ERC20Votes) {
    super._afterTokenTransfer(from, to, amount);
  }

  function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
    super._mint(to, amount);
  }

  function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
    super._burn(account, amount);
  }
}