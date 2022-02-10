// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract CookieClicker is ERC721 {

  constructor() ERC721("COOKIE_GAME", "CG") {}

  uint256 _counter;

  IERC20 public cookies;

  uint256 constant public BASE_GRANDMA_FEE = 30 ether;
  uint256 constant MINTING_FEE = 0.0001 ether;
  mapping(uint256 => NFTStats) _nfts;

  struct NFTStats {
    uint256 cookiesPerSecond;
    uint256 lastUpdateTime;
    uint256 rewardsDue;
  }

  modifier updateReward(uint256 tokenId) {
    _nfts[tokenId].rewardsDue += (block.timestamp - _nfts[tokenId].lastUpdateTime) * _nfts[tokenId].cookiesPerSecond;
    _nfts[tokenId].lastUpdateTime = block.timestamp;
    _;
  }

  function mint(uint256 amount) public payable {
    require(msg.value > amount * MINTING_FEE);
    for(uint256 i = 0; i < amount; i++) {
      __mint(msg.sender);
    }
  }

  function __mint(address recipient) internal {
    _mint(recipient, _counter);
    _nfts[_counter] = NFTStats(1 ether, block.timestamp, 0);
    _counter += 1;
  }

  function getRewards(uint256 tokenId) public updateReward(tokenId) {
    address owner = ownerOf(tokenId);
    cookies.transfer(owner, _nfts[tokenId].rewardsDue);
  }

  function buyGrandma(uint256 tokenId) public updateReward(tokenId) {
    getRewards(tokenId);
    address owner = ownerOf(tokenId);
    require(msg.sender == owner);
    cookies.transferFrom(owner, address(this), BASE_GRANDMA_FEE);
    _nfts[tokenId].cookiesPerSecond += 3 ether / 10;
  }

  function buyFactory(uint256 tokenId) public updateReward(tokenId) {
    address owner = ownerOf(tokenId);
    require(msg.sender == owner);
    cookies.transferFrom(owner, address(this), 3 * BASE_GRANDMA_FEE);
    _nfts[tokenId].cookiesPerSecond += 10 ether / 10;
  }

  function withdrawEther() public {
    msg.sender.call{ value: address(this).balance }("");
  }

  function viewMyNft(uint256 tokenId) external view returns(NFTStats memory) {
    return _nfts[tokenId];
  }

  function setCookiesContract(address _cookies) public {
    require(address(cookies) == address(0));
    cookies = IERC20(_cookies);
  }
}