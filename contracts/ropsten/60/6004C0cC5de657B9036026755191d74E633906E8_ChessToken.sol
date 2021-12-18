//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import './Chess.sol';

contract ChessToken is Ownable, ERC721 {
  
  Chess private _chess;
  string private _baseUri;
  string private _contractUri;
  

  constructor(
    address payable addr,
    string memory baseUri,
    string memory contractUri
    ) ERC721("BlockChain Chess Club Trophies", "BCCC") {
      _chess = Chess(addr);
      _baseUri = baseUri;
      _contractUri = contractUri;
    }
  
  function claim(uint _id) external {
    Chess.Game memory g = _chess.getGameById(_id);
    require(g.winner == msg.sender, 'Must be winner to mint NFT');
    _safeMint(msg.sender, _id, '');
  }

  function setBaseURI(string calldata uri) external onlyOwner {
    _baseUri = uri;
  }

  function setContractURI(string calldata uri) external onlyOwner {
    _contractUri = uri;
  }

  function chessClubAddress() public view returns (address) {
    return address(_chess);
  }

  // Opensea
  function contractURI() public view returns (string memory) {
    return _contractUri;
  }
  
  // ERC721 overrides
  function _baseURI() override internal view returns (string memory) {
    return _baseUri;
  }
  
}