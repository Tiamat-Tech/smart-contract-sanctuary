// SPDX-License-Identifier: MIT

/*
            _ _____                      _               
           | |  __ \                    (_)              
         __| | |  \/ ___ _ __   ___  ___ _ ___           
        / _` | | __ / _ \ '_ \ / _ \/ __| / __|          
       | (_| | |_\ \  __/ | | |  __/\__ \ \__ \          
        \__,_|\____/\___|_| |_|\___||___/_|___/          
                                                         
                                                         
                   _ _____  _____ _   _                  
                  | |  __ \|  ___| \ | |                 
                __| | |  \/| |__ |  \| |                 
               / _` | | __ |  __|| . ` |                 
              | (_| | |_\ \| |___| |\  |                 
               \__,_|\____/\____/\_| \_/                 
                                                         
                                                         
  ___        _                        _                  
 / _ \      | |                      | |                 
/ /_\ \_   _| |_ ___  _ __ ___   __ _| |_ ___  _ __  ___ 
|  _  | | | | __/ _ \| '_ ` _ \ / _` | __/ _ \| '_ \/ __|
| | | | |_| | || (_) | | | | | | (_| | || (_) | | | \__ \
\_| |_/\__,_|\__\___/|_| |_| |_|\__,_|\__\___/|_| |_|___/  
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract dGenesisCCA is ERC721, ERC721Enumerable, Ownable {
    bool private _active;
    string private _baseURIextended;
	uint256 private _activeTime;
    uint constant MAX_TOKENS = 2000;
    uint constant NUM_RESERVED_TOKENS = 30;
    address constant SHAREHOLDERS_ADDRESS = 0xFcfD26569bE92B1cf46811bca2D45b0BFc3664C3; 

    constructor() ERC721("dGenesis Cyclic Cellular Automatons", "dGENCCA") {
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }
	
	function activate() external onlyOwner() {
        require(!_active, "Already active");
        _activeTime = block.timestamp;
        _active = true;
    }
	
	function timeToSale() external view returns(uint256) {
        require(_active, "Inactive");
        if (block.timestamp >= (_activeTime + 3600)) return 0;
        return (_activeTime + 3600) - block.timestamp;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }
	
	


    function reserve() public onlyOwner {
        uint supply = totalSupply();
        uint i;
        for (i = 0; i < NUM_RESERVED_TOKENS; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }
    
    
    function mint(uint numberOfTokens) public payable {
        require(_active, "Inactive");
		require(block.timestamp >= _activeTime + 3600, "Purchasing not active");
        require(numberOfTokens <= 20, "Exceeded max purchase amount");
        require(totalSupply() + numberOfTokens <= MAX_TOKENS, "Purchase would exceed max supply of tokens");
        require(0.09 ether * numberOfTokens <= msg.value, "Ether value sent is not correct");
        
        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            if (totalSupply() < MAX_TOKENS) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(SHAREHOLDERS_ADDRESS).transfer(balance);
    }
}