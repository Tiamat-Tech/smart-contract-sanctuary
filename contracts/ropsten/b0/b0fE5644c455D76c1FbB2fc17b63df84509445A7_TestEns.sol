// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract TestEns is ERC20, Ownable {
  using SafeMath for uint256;
  uint256 constant maxSupply = 1000000000000000;
  bool _completed = false;
  mapping (bytes32 => bool) private _claims;

  ENS ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

  constructor()
        ERC20("Test", "Test")
    {
      uint256 _amountDevAndCommunity = maxSupply.div(100).mul(3);
      _mint(msg.sender, _amountDevAndCommunity.mul(10 ** uint(decimals())));
    }

    function test(bytes32 node) external {
      Resolver resolver = ens.resolver(node);
      address resolvedAddress = resolver.addr(node);
      require(msg.sender == resolvedAddress, "Not authorized");
      require(_claims[node] == false, "Already claimed");
      _claims[node] = true;
    }

    function setEnsResolver(address resolverAddress) public onlyOwner {
      ens = ENS(resolverAddress);
    }

}

abstract contract ENS {
    function resolver(bytes32 node) public virtual view returns (Resolver);
}

abstract contract Resolver {
    function addr(bytes32 node) public virtual view returns (address);
}