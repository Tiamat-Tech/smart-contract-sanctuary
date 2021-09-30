//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import './OperatorHub.sol';
import './ERC721Mintable.sol';

contract ForeignGate is OperatorHub {
  mapping(bytes32 => bool) usedHashes;

  constructor(uint8 requiredOperators_, address[] memory initialOperators)
    OperatorHub(requiredOperators_, initialOperators) {
  }

  function canMint(
    bytes32 transactionHash,
    address tokenContract,
    address recipient,
    uint256 value,
    uint8[] memory v,
    bytes32[] memory r,
    bytes32[] memory s
  ) public view returns (bool) {
    require(tokenContract != address(0x0), "should provide a token contract");
    require(recipient != address(0x0), "should provide a recipient");
    require(value > 0, "should provide value");
    require(transactionHash > 0, "TX hash should be provided");

    bytes32 hash = prefixed(keccak256(abi.encodePacked(transactionHash, tokenContract, recipient, value)));

    return usedHashes[hash] == false;
  }

  function mint(
    bytes32 transactionHash,
    address tokenContract,
    address recipient,
    uint256 value,
    uint8[] memory v,
    bytes32[] memory r,
    bytes32[] memory s
  ) external {
    require(tokenContract != address(0x0), "should provide a token contract");
    require(recipient != address(0x0), "should provide a recipient");
    require(value > 0, "should provide value");
    require(transactionHash > 0, "TX hash should be provided");

    bytes32 hash = prefixed(keccak256(abi.encodePacked(transactionHash, tokenContract, recipient, value)));

    require(usedHashes[hash] == false, "already minted");
    usedHashes[hash] = true;

    require(v.length > 0, "should provide signatures at least one signature");
    require(v.length == r.length, "should the same number of inputs for signatures (r)");
    require(v.length == s.length, "should the same number of inputs for signatures (s)");

    require(checkSignatures(hash, v.length, v, r, s) >= requiredOperators, "not enough signatures to proceed");

    ERC721Mintable(tokenContract).mintTo(recipient, value);

    emit LogMint(transactionHash, tokenContract, recipient, value);
  }

  function mintAndCall(
    bytes32 transactionHash,
    address tokenContract,
    address recipient,
    uint256 value,
    uint8[] memory v,
    bytes32[] memory r,
    bytes32[] memory s,
    address target,
    bytes memory calldata_
  ) external {
    this.mint(transactionHash, tokenContract, recipient, value, v, r, s);

    assembly {
      let succeeded := call(gas(), target, 0, add(calldata_, 0x20), mload(calldata_), 0, 0)

      switch iszero(succeeded)
        case 1 {
          // throw if delegatecall failed
          let size := returndatasize()
          returndatacopy(0x00, 0x00, size)
          revert(0x00, size)
        }
    }
  }

  /**
   * @dev Transfers ownership of the token contract to a new account (`newOwner`).
   * Can only be called if the  the current owner.
   */
  function transferTokenOwnership(address tokenContract, address newOwner) external onlyOwner {
    Ownable(tokenContract).transferOwnership(newOwner);
  }

  event LogMint(bytes32 transactionHash, address tokenContract, address recipient, uint256 value);
}