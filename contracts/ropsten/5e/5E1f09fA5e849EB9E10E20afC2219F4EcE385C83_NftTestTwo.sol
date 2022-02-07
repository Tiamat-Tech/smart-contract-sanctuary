//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NftTestTwo is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    uint public constant PRICE = 0.0001 ether;

    string public baseTokenURI;
    uint[2] openTokens;
    uint[] soldedTokenIds;

    constructor(string memory baseURI)  ERC721("NFT TEST TWO", "NFTC") {
        setBaseURI(baseURI);
    }

    function reserveNFTs(uint _tokenId) public onlyOwner {
        _mintSingleNFT(_tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function setOpenTokens(uint one, uint two) public onlyOwner {
        openTokens[0] = one;
        openTokens[1] = two;
    }

    function mintNFTs(uint _tokenId) public payable {
        require(_tokenId >= openTokens[0] && _tokenId <= openTokens[1], "Token is closed");
        bool isTokenSold = false;
        for (uint i = 0; i < soldedTokenIds.length; i++) {
            if(soldedTokenIds[i] == _tokenId) {
                isTokenSold = true;
                break;
            }
        }
        require(!isTokenSold, "Token is solded");
        require(msg.value >= PRICE, "Not enough ether to purchase NFTs.");
        _mintSingleNFT(_tokenId);
    }

    function _mintSingleNFT(uint _tokenId) private {
        _safeMint(msg.sender, _tokenId);
        soldedTokenIds.push(_tokenId);
    }

    function tokensOfOwner(address _owner) external view returns (uint[] memory) {
        uint tokenCount = balanceOf(_owner);
        uint[] memory tokensId = new uint256[](tokenCount);
        for (uint i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    function withdraw() public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");
        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    function getBalance() external view onlyOwner returns (uint) {
        return address(this).balance;
    }


    function getSoldTokenIds() external view onlyOwner returns (uint[] memory) {
        return soldedTokenIds;
    }

    function getOpenTokens() external view onlyOwner returns (uint[2] memory) {
        return openTokens;
    }
}