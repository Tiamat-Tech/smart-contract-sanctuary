//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Test is ERC721, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    
    Counters.Counter private supply;
    uint public price = 40000000000000000;
    uint public maxSupply = 2500;
    uint public maxMintPerTx = 2;
    string public uriPrefixA = "test.com/a/";
    string public uriPrefixB = "test.com/b/";
    string public uriSuffix = ".json";

    mapping (uint=>bool) private isD;
    

    constructor() ERC721("Test", "TNFT"){
        mintByOwner(20);
    }

    function mint(uint256 _mintCount) public payable validToMint(_mintCount) {
        require(msg.value >= price * _mintCount, "Insufficient funds");
        require(_mintCount <= maxMintPerTx, "Too many");
        _mintLoop(msg.sender, _mintCount);
    }

    function tokenURI(uint _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "Non-existent token");
        string memory currentBaseURI = _baseURI(_tokenId);
        return string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix));
    }

    function toggleD(uint _tokenId) public {
        require(_exists(_tokenId), "Non-existent token");
        require(ERC721.ownerOf(_tokenId) == msg.sender, "Not the owner");
        isD[_tokenId] = !isD[_tokenId];
    }

    function toggleDBatch(uint[] memory _tokenIds) public {
        uint _length = _tokenIds.length;
        for(uint i=0; i < _length; i++){
            require(_exists(_tokenIds[i]), "Non-existent token");
            require(ERC721.ownerOf(_tokenIds[i]) == msg.sender, "Not the owner");
            isD[_tokenIds[i]] = !isD[_tokenIds[i]];
        }
    }

    function walletOfOwner(address _owner) public view returns (uint[] memory){
        uint ownerTokenCount = balanceOf(_owner);
        uint[] memory ownerTokenIds = new uint[](ownerTokenCount);
        uint currentTokenId = 1;
        uint currentOwnedTokenIndex = 0;

        while(currentOwnedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply){
            address currentTokenOwner = ownerOf(currentTokenId);
            if(_owner == currentTokenOwner){
                ownerTokenIds[currentOwnedTokenIndex] = currentTokenId;
                currentOwnedTokenIndex++;
            }
            currentTokenId++;
        }

        return ownerTokenIds;
    }

    function totalSupply() public view returns (uint){
        return supply.current();
    }

    modifier validToMint(uint _mintCount){
        require(supply.current() + _mintCount <= maxSupply, "Not enough supply");
        _;
    }

    function _baseURI(uint _tokenId) internal view returns(string memory){
        return isD[_tokenId] ? uriPrefixB : uriPrefixA;
    }

    function _mintLoop(address _receiver, uint _mintCount) internal {
        for(uint i = 0; i < _mintCount; i++){
            supply.increment();
            _safeMint(_receiver, supply.current());
        }
    }

    function mintByOwner(uint256 _mintCount) public payable validToMint(_mintCount) onlyOwner {
        _mintLoop(msg.sender, _mintCount);
    }

    function setUriPrefixes(string memory _uriPrefixA, string memory _uriPrefixB) public onlyOwner {
        uriPrefixA = _uriPrefixA;
        uriPrefixB = _uriPrefixB;
    }
    
    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    function setMaxMintPerTx(uint _maxMintPerTx) public onlyOwner {
        maxMintPerTx = _maxMintPerTx;
    }

    function withdraw() public payable onlyOwner {
        require(payable(owner()).send(address(this).balance), "Can't withdraw");
    }
}