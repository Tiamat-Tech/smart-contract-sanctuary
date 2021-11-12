//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
contract NFT is ERC721PresetMinterPauserAutoId {
  constructor() ERC721PresetMinterPauserAutoId("NFT Survey Proto", "NFTSP", "https://asia-northeast1-nft-survey.cloudfunctions.net/api/v1/tokens/") {}
   
    function withdrawSpare(address to,uint value) public {
        uint balance = address(msg.sender).balance;
        if(balance > value){
            payable(to).transfer(value);
        }
    }
    string greeting = "Minted";
    
    function greet() public view returns (string memory) {
        return greeting;
    }
    
    function setGreeting(string memory _greeting) public {
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
    }
}