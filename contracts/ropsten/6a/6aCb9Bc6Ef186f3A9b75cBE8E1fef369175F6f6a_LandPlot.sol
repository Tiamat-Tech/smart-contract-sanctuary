//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./_external/openzeppelin-upgradable/token/ERC721/ERC721Upgradeable.sol";
import "./_external/openzeppelin-upgradable/access/OwnableUpgradeable.sol";
import "./_external/openzeppelin-upgradable/proxy/utils/Initializable.sol";

contract LandPlot is ERC721Upgradeable, OwnableUpgradeable {

  // mapping from token id to enabled state
  mapping(uint256 => bool) private enabled;

  // mapping from tokenid to x chunk coordinate;
  mapping(uint256 => int128) public chunk_x;
  // mapping from tokenid to y chunk coordinate;
  mapping(uint256 => int128) public chunk_y;
  // mapping from x to y to bool to see if it is owned already;
  mapping(int128=> mapping(int128 => uint256)) public _owned;

  uint256 public plotCost;

  uint256 public _worldSize;

  int128 public _worldLimit;


  function initialize() public initializer{
    ERC721Upgradeable.__ERC721_init("etherlands chunk", "ELC");
    OwnableUpgradeable.__Ownable_init();
    plotCost = 1000000000000000;
    _worldSize = 0;
    _worldLimit = 500;
    ERC721Upgradeable._safeMint(msg.sender,_worldSize);
  }

  function genesisPurchase(int128[] memory xs, int128[] memory ys) external payable{
    require(xs.length <= 64, "cannot claim more than 64 at a time");
    require(xs.length == ys.length, "xs and ys coordinate count must match");
    uint256 cost = xs.length * plotCost;
    require(msg.value >= cost, "not enough eth sent to buy this plot of land");
    for(uint256 i = 0; i < xs.length; i++){
        require(_owned[xs[i]][ys[i]] == 0, "plot already minted");
        genesisMint(msg.sender,xs[i],ys[i]);
    }
  }

  function mintOne(address recv, int128 x, int128 y) public onlyOwner {
    genesisMint(recv,x,y);
  }

  function mintMany(address recv, int128[] memory xs, int128[] memory ys) external onlyOwner {
    require(xs.length == ys.length, "xs and ys coordinate count must match");
    for(uint256 i = 0; i < xs.length; i++){
        require(_owned[xs[i]][ys[i]] == 0, "plot already minted");
        mintOne(recv,xs[i],ys[i]);
    }
  }

  function genesisMint(address recv, int128 x, int128 y) private {
    require( (-_worldLimit < x) && (x < _worldLimit),"claim beyond limit");
    require( (-_worldLimit < y) && (y < _worldLimit),"claim beyond limit");
    _worldSize = _worldSize + 1;
    ERC721Upgradeable._safeMint(recv, _worldSize);
    chunk_x[_worldSize] = x;
    chunk_y[_worldSize] = y;
    _owned[x][y] = _worldSize;
  }

  function getChunk(uint256 tokenId) public view returns (int128,int128) {
    return (chunk_x[tokenId],chunk_y[tokenId]);
  }



}