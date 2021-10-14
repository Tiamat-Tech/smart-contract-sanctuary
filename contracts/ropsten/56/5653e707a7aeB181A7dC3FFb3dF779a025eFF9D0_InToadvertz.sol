// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC721Enumerable.sol";
import "Ownable.sol";

contract InToadvertz is ERC721Enumerable, Ownable
{
    uint256 public constant _price = 0.05 ether;
    uint256 public constant _maxSupply = 100;    
    uint256 public constant _tokensAllowedPerMint = 20;

    bool public _bIsPaused = true;
    string private _currentBaseURI;
    string private _contractURI;

    constructor() 
    ERC721("InToadvertz", "ITOADZ")
    {
        _currentBaseURI = "ipfs://QmWEFSMku6yGLQ9TQr66HjSd9kay8ZDYKbBEfjNi4pLtrr/";
        _contractURI = "ipfs://QmV1SZzgaCWGvExViNRaRYg396NgEknp4cmYihcrJSPhKm";
    }

    function mint(uint256 numberOfMints) public payable
    {
        uint256 supply = totalSupply();

        require(!_bIsPaused, "Sale is currently paused.");
        require(numberOfMints > 0 && numberOfMints <= _tokensAllowedPerMint, "Invalid purchase amount.");
        require((supply + numberOfMints) < _maxSupply, "Purchase would exceed max supply of tokens.");
        require((_price * numberOfMints) == msg.value, "Ether value sent is not correct.");

        for(uint256 i; i < numberOfMints; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function setBaseURI(string memory inBaseURI) public onlyOwner
    {
        _currentBaseURI = inBaseURI;
    }

    function togglePaused() public onlyOwner
    {
        _bIsPaused = !_bIsPaused;
    }

    function withdraw() public onlyOwner
    {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setContractURI(string memory inContractURI) public onlyOwner
    {
        _contractURI = inContractURI;
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function _baseURI() internal view virtual override returns (string memory)
    {
        return _currentBaseURI;
    }
}