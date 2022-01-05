// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Namehash.sol";
import "./ENS.sol";
import "./Resolver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract TestRR is ERC20, Ownable {
  using SafeMath for uint256;
  uint256 constant maxSupply = 1000000000000000;
  mapping (bytes32 => bool) private _nodes;

  ENS _ens;
  bytes32 private constant ADDR_REVERSE_NODE = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

  constructor(address ensAddr)
        ERC20("TestRR", "TestRR")
    {
      _ens = ENS(ensAddr);
      uint256 _amountDevAndCommunity =  maxSupply.div(100).mul(30);
      _mint(msg.sender, _amountDevAndCommunity.mul(10 ** uint(decimals())));

    }

    // function testENSRR() external {
    //   address[] memory t = new address[](1);
    //   t[0] = msg.sender;
    //   string[] memory names = ensReverseRecords.getNames(t);
    //   string memory name = names[0];
    //   require(bytes(name).length != 0, "Not authorized");
    //   bytes32 node = Namehash.namehash(name);
    //   require(_nodes[node] == false, "Already claimed");
    //   require(node.length != 0, "Not authorized");
    //   _nodes[node] = true;
    //    uint256 _amount = maxSupply.div(10000).mul(10 ** uint(decimals()));
    //   _transfer(address(this), msg.sender, _amount);
    // }

    function getName(address add) external view returns (string memory r) {
            bytes32 node = _node(add);
            address resolverAddress = _ens.resolver(node);
            if(resolverAddress != address(0x0)){
                Resolver resolver = Resolver(resolverAddress);
                string memory name = resolver.name(node);
                if(bytes(name).length == 0 ){
                    return "NOT FOUND";
                }
                bytes32 namehash = Namehash.namehash(name);
                address forwardResolverAddress = _ens.resolver(namehash);
                if(forwardResolverAddress != address(0x0)){
                    Resolver forwardResolver = Resolver(forwardResolverAddress);
                    address forwardAddress = forwardResolver.addr(namehash);
                    if(forwardAddress == add){
                        return name;
                    }
                }
            }
            return "NOT FOUND";
     }

    function setRR(address ensAddress) public onlyOwner {
      _ens = ENS(ensAddress);
    }

    function _node(address addr) private pure returns (bytes32) {
      return keccak256(abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(addr)));
    }

    function sha3HexAddress(address addr) private pure returns (bytes32 ret) {
      addr;
      ret; // Stop warning us about unused variables
      assembly {
          let lookup := 0x3031323334353637383961626364656600000000000000000000000000000000
          for { let i := 40 } gt(i, 0) { } {
              i := sub(i, 1)
              mstore8(i, byte(and(addr, 0xf), lookup))
              addr := div(addr, 0x10)
              i := sub(i, 1)
              mstore8(i, byte(and(addr, 0xf), lookup))
              addr := div(addr, 0x10)
          }

          ret := keccak256(0, 40)
      }
    }

}