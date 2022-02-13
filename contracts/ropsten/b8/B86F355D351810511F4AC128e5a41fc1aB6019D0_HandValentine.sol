// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

contract HandValentine is ERC721URIStorage, Ownable {

    uint8 public counter = 0;
    address payable[] public team;
    uint256[] public shares;
    uint256 basePrice= 0.02 ether;
    // uint public defaultFreeMints = 1;
    uint public maxMintsPerWallet = 50;
    mapping(address => uint) public mintedNFTs;
    
    constructor() ERC721("Project Snooze", "SHP")  {
        team=[
            payable(0x5172c410aD20d27763c686Ada1458d2c00e145D3)
        ];
        shares=[100];
    }
    
    function dividends() public onlyOwner payable {
        uint256 total = address(this).balance;
        for (uint256 i = 0; i < team.length; i++) {
            team[i].transfer((total * (shares[i] * 100)) / 10000);
        } 
    }

    function mint(string memory tokenURI) public payable returns (uint) {
        require(counter < 10000, "Tokens supply reached limit");
        require(msg.value >= basePrice,  "Minimum token price is 0.02 ETH.");
        _mint(msg.sender, counter);
        _setTokenURI(counter, tokenURI);
        counter += 1;
        return counter;
    }
}