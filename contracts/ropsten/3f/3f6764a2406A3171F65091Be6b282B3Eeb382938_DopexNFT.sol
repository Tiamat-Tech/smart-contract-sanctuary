// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DopexNFT is ERC721, ERC721Enumerable, Ownable {

    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIdCounter;
    uint256 public mintRate = 0.05 ether;
    uint256 public MAX_SUPPLY = 20;
    uint256 public MAX_MINT = 3;
    string public baseURI;
    string public baseExtension = ".json";
    uint256[] public mintIDremaining;

    constructor() ERC721("DopexNFT", "DPXNFT") {
        for (uint256 i=0; i < MAX_SUPPLY; i++) {
            mintIDremaining.push(i);
        }
    }

    function random(uint256 n) internal view returns (uint256) {
        uint256 randomnumber = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, block.difficulty))) % n;
        randomnumber = randomnumber;
        return randomnumber;
        }

    function removeID(uint256 _index) internal {
        require(_index < mintIDremaining.length);
        for (uint256 i=_index; i< mintIDremaining.length; i++) {
            mintIDremaining[i] = mintIDremaining[i+1];
            }
        mintIDremaining.pop();
    }
    
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
        }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
        }

    function tokenURI(uint256 _tokenURI) public view virtual override returns (string memory) {
        require(_exists(_tokenURI), "ERC721Metadata: URI query for nonexistent token");

        string memory base = _baseURI();
            
        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI.toString();
        }

        return string(abi.encodePacked(base, _tokenURI.toString()));
    }

    function safeMint(address to, uint _mintNumber) public payable {
        
        require(_mintNumber > 0, 'Need to mint positive number of tokens');
        require(_mintNumber <= MAX_MINT, "Attempting to mint more than mint limit");
        require(_mintNumber + _tokenIdCounter.current() <= MAX_SUPPLY, "Can not mint more than total maximum supply");
        require(msg.value >= mintRate * _mintNumber, "Not enough eth sent");

        for (uint i=0; i<_mintNumber; i++) {

            uint256 randomMintID = random(mintIDremaining.length);
            _safeMint(to, randomMintID);
            removeID(randomMintID);
            _tokenIdCounter.increment();
        }
    }

    function withdraw() public onlyOwner {
        require(address(this).balance > 0);
        payable(owner()).transfer(address(this).balance);
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
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