// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract CookieClicker is ERC721Enumerable {

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
    require(msg.value >= amount * MINTING_FEE);
    uint256 toBeMintedNext = _counter;
    for(uint256 i = 0; i < amount; i++) {
      _mint(msg.sender, toBeMintedNext);
      _nfts[toBeMintedNext] = NFTStats(1 ether, block.timestamp, 0);
      toBeMintedNext += 1;
    }
    _counter = toBeMintedNext;
  }

  function getRewards(uint256 tokenId) public updateReward(tokenId) {
    address owner = ownerOf(tokenId);
    uint256 rewards = _nfts[tokenId].rewardsDue;
    _nfts[tokenId].rewardsDue = 0;
    cookies.transfer(owner, rewards);
  }

  function buyGrandma(uint256 tokenId) public {
    getRewards(tokenId);
    address owner = ownerOf(tokenId);
    require(msg.sender == owner);
    cookies.transferFrom(owner, address(this), BASE_GRANDMA_FEE);
    _nfts[tokenId].cookiesPerSecond += 3 ether / 10;
  }

  function buyFactory(uint256 tokenId) public {
    getRewards(tokenId);
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

  function viewPendingCookiesRewardForUser(address account) external view returns(uint256 sum) {
    uint256 balance = balanceOf(account);
    balance = balance <= 5 
      ? balance
      : 5;
    for(uint256 i = 0; i < balance; i++) {
      sum += viewPendingCookiesRewardForToken(tokenOfOwnerByIndex(account, i));
    }
  }

  function viewPendingCookiesRewardForToken(uint256 tokenId) public view returns(uint256) {
    NFTStats storage stats = _nfts[tokenId];
    return stats.rewardsDue + (block.timestamp - stats.lastUpdateTime) * stats.cookiesPerSecond;
  }


  function setCookiesContract(address _cookies) public {
    require(address(cookies) == address(0));
    cookies = IERC20(_cookies);
  }
}