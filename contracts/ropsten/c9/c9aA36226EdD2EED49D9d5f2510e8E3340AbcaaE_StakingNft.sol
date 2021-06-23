// SPDX-License-Identifier: UNLICENSED

// Code by zipzinger and cmtzco
// DEFIBOYS
// defiboys.com

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract StakingNft is ERC721Enumerable, Ownable {

    event NFTPurchased(address to, uint256 id);

    mapping(address => bool) validOwner;
    uint256 public nftIndex;
    string public baseURI;
    uint256 public maxNftCount;
    uint256 public currentPrice;

    constructor (address _stakingContract, uint256 _maxNftCount, uint256 _currentPrice, string memory nftName, string memory nftSymbol) ERC721(nftName, nftSymbol) {
        validOwner[_stakingContract] = true;
        validOwner[msg.sender] = true;
        maxNftCount = _maxNftCount;
        currentPrice = _currentPrice;
    }

    function setCurrentPrice(uint256 _currentPrice) public onlyOwner {
        require(_currentPrice > 0, "NFT sale price must be higher than 0.");
        currentPrice = _currentPrice;
    }

    function addValidOwner(address _addr) public onlyOwner {
        validOwner[_addr] = true;
    }

    function mintToAddress(address _addr) public {
        require(validOwner[msg.sender] == true, "Not allowed to mint NFTs");

        uint256 testNum = SafeMath.add(nftIndex, 1);
        require(testNum <= maxNftCount, "NFT sold out");

        nftIndex += 1;
        _safeMint(_addr, nftIndex);
        emit NFTPurchased(_addr, nftIndex);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _baseURIInput) public onlyOwner {
        baseURI = _baseURIInput;
    }

    function setMaxNFTCount(uint256 _count) public onlyOwner {
        require(_count > maxNftCount, "maxNFTCount must be larger than previous value");
        maxNftCount = _count;
    }

}