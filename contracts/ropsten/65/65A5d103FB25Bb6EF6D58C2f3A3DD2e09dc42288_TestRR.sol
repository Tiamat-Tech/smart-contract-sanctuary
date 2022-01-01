// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Namehash.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract TestRR is ERC20, Ownable {
  using SafeMath for uint256;
  uint256 constant maxSupply = 1000000000000000;
  mapping (bytes32 => bool) private _nodes;
  ReverseRecords ensReverseRecords;

  constructor(address ensReverseRecordsAddress)
        ERC20("TestRR", "TestRR")
    {
      ensReverseRecords = ReverseRecords(ensReverseRecordsAddress);
      uint256 _amountDevAndCommunity =  maxSupply.div(100).mul(30);
      _mint(msg.sender, _amountDevAndCommunity.mul(10 ** uint(decimals())));

    }

    function testENSRR() external {
      address[] memory t = new address[](1);
      t[0] = msg.sender;
      string[] memory names = ensReverseRecords.getNames(t);
      string memory name = names[0];
      require(bytes(name).length != 0, "Not authorized");
      bytes32 node = Namehash.namehash(name);
      require(_nodes[node] == false, "Already claimed");
      require(node.length != 0, "Not authorized");
      _nodes[node] = true;
    //  uint256 _amount = maxSupply.div(1000).mul(10 ** uint(decimals()));
    //  _transfer(address(this), msg.sender, _amount);
    }

    function setRR(address ensRRAddress) public onlyOwner {
      ensReverseRecords = ReverseRecords(ensRRAddress);
    }

}

abstract contract ReverseRecords {
    function getNames(address[] calldata addresses) external virtual view returns (string[] memory r);
}