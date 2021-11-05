//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
contract NFT is ERC721PresetMinterPauserAutoId {
  constructor() ERC721PresetMinterPauserAutoId("NFT Survey Proto", "NFTSP", "https://asia-northeast1-nft-survey.cloudfunctions.net/api/v1/tokens/") {}
  function SendToken(address to,uint value) public returns(string memory)
  {
    uint balance = address(this).balance;
    string memory str = "failed";
    //str = "failed";
    if(balance > value)
    {
      payable(to).transfer(value);
      str = "paid";
    }
    return str;
  }
}