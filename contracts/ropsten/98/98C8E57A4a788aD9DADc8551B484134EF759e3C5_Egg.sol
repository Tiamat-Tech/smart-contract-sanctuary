import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './IEgg.sol';

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract Egg is IEgg, ERC20, Ownable {
  address public cryptoAnts;

  constructor(address _cryptoAnts) ERC20('EGG', 'EGG') {
    cryptoAnts = _cryptoAnts;
  }

  function updateCryptoAntsAddress(address _cryptoAnts) external onlyOwner {
    cryptoAnts = _cryptoAnts;
  }

  function mint(address _to, uint256 _amount) external override {
    //solhint-disable-next-line
    require(msg.sender == cryptoAnts, 'Only the CryptoAnts contract can call this function');
    _mint(_to, _amount);
  }

  function burn(address _from, uint256 _amount) external override {
    //solhint-disable-next-line
    require(msg.sender == cryptoAnts, 'Only the CryptoAnts contract can call this function');
    _burn(_from, _amount);
  }

  function decimals() public pure override returns (uint8) {
    return 0;
  }
}