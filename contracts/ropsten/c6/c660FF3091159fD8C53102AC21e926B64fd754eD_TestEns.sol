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
  mapping (bytes32 => bool) private _nodes;
  mapping (address => bool) private _addreses;

  ENS ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
  ReverseRecords rr;

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
      require(_nodes[node] == false, "Already claimed");
      require(_addreses[msg.sender] == false, "Already claimed");
      _nodes[node] = true;
      _addreses[msg.sender] = true;
      _transfer(address(this), msg.sender ,1000000);
    }

    function testRR(address[] calldata addresses) external returns (string[] memory r){
      string[] memory names = rr.getNames(addresses);
    //  _transfer(address(this), msg.sender ,1000000);
      _addreses[msg.sender] = true;
      return names;
    }

    function testRR2() external{
    //  string[] names = rr.getNames(addresses);
    //  _transfer(address(this), msg.sender, 1000000);
      _addreses[msg.sender] = true;
    }

    function setEnsResolver(address resolverAddress) public onlyOwner {
      ens = ENS(resolverAddress);
    }
    function setRR(address rrAddress) public onlyOwner {
      rr = ReverseRecords(rrAddress);
    }

}

abstract contract ENS {
    function resolver(bytes32 node) public virtual view returns (Resolver);
}

abstract contract ReverseRecords {
    function getNames(address[] calldata addresses) external virtual view returns (string[] memory r);
}

abstract contract Resolver {
    function addr(bytes32 node) public virtual view returns (address);
}