// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "./Namehash.sol";
//import "./ENS.sol";
//import "./Resolver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract TestToken is ERC20, ERC20Permit, ERC20Votes,  Ownable {
  using SafeMath for uint256;
  uint256 constant maxSupply = 1000000000000000;

  constructor()
        ERC20("TestToken Token", "TestToken")
        ERC20Permit("TestToken")

    {
      // 2% for dev & 1% for community
      uint256 _amountDevAndCommunity = maxSupply.div(100).mul(3);
      // 60% airdrop
      uint256 _amountAirDrop =  maxSupply.div(100).mul(60);
      // 7% for daos
      uint256 _amountDao =  maxSupply.div(100).mul(7);
      // 30% burned
      uint256 _amountBurn =  maxSupply.div(100).mul(30);
      _mint(msg.sender, _amountDevAndCommunity.mul(10 ** uint(decimals())));
      _mint(address(this), _amountAirDrop.mul(10 ** uint(decimals())));
      _mint(msg.sender, _amountDao.mul(10 ** uint(decimals())));
      _mint(msg.sender, _amountBurn.mul(10 ** uint(decimals())));
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
     internal
     override(ERC20, ERC20Votes)
   {
       super._afterTokenTransfer(from, to, amount);
   }

   function _mint(address to, uint256 amount)
       internal
       override(ERC20, ERC20Votes)
   {
       super._mint(to, amount);
   }

   function _burn(address account, uint256 amount)
       internal
       override(ERC20, ERC20Votes)
   {
       super._burn(account, amount);
   }
}