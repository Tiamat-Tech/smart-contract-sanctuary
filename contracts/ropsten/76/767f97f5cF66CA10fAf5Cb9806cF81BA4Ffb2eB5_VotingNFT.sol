//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract VotingNFT is ERC721Enumerable, ERC721URIStorage, Ownable {

  using SafeMath for uint256;
  using Address for address;

  uint256 public maxSuply;
  address public masterVote;
  
  constructor(string memory name, string memory symbol, uint256 supply, address inputMaster) ERC721(name, symbol) {
    maxSuply = supply;
    masterVote = inputMaster;
  }

  function register(bytes32 _messageHash, bytes memory _signature) external payable {
    uint256 currentSuply = totalSupply();
    require(currentSuply < maxSuply, "Max Supply Reached");
    require(verifySigner(masterVote, _signature, _messageHash), "Not Authorized");
    require(balanceOf(msg.sender) == 0, "Already minted");
    _safeMint(msg.sender, currentSuply + 1);
  }

  function getEthSignedMessageHash(bytes32 _messageHash)
        public
        pure
        returns (bytes32)
  { 
    return
        keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
        );
  }

  function verifySigner(
        address signer,
        bytes memory _signature,
        bytes32 _messageHash
  ) internal pure returns (bool) {
    (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
    bytes32 ethSignedMessageHash = getEthSignedMessageHash(_messageHash);
    return ECDSA.recover(ethSignedMessageHash, v, r, s) == signer;
  }

  function splitSignature(bytes memory sig)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
  {
      require(sig.length == 65, "invalid signature length");

      assembly {
          /*
          First 32 bytes stores the length of the signature

          add(sig, 32) = pointer of sig + 32
          effectively, skips first 32 bytes of signature

          mload(p) loads next 32 bytes starting at the memory address p into memory
          */

          // first 32 bytes, after the length prefix
          r := mload(add(sig, 32))
          // second 32 bytes
          s := mload(add(sig, 64))
          // final byte (first byte of the next 32 bytes)
          v := byte(0, mload(add(sig, 96)))
      }

      // implicitly return (r, s, v)
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}