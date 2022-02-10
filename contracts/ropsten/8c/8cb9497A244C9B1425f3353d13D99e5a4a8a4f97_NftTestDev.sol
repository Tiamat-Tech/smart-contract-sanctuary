//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NftTestDev is ERC721Enumerable, Ownable {

    // price for one token
    uint private constant PRICE = 0.001 ether;
    // price for random token
    uint private constant PRICE_RANDOM = 0.0001 ether;

    // token url
    string public baseTokenURI;
    // open tokens data
    uint[2] openTokens;
    // sold tokens
    uint[] soldedTokenIds;

    event MintNft(address senderAddress, uint256 nftToken);
    event Withdraw(uint balance, uint one, uint two, uint th);
    event BaseURI(string url);
    event OpenTokens(uint[2] openedTokens);


    constructor(string memory baseURI)  ERC721("NFT TEST DEV", "NFTC") {
        setBaseURI(baseURI);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
        emit BaseURI(baseTokenURI);
    }

    function setOpenTokens(uint one, uint two) public onlyOwner {
        openTokens[0] = one;
        openTokens[1] = two;
        emit OpenTokens(openTokens);
    }

    function reserveNFT(uint _tokenId) public onlyOwner {
        require(!checkSoldTokens(_tokenId), "Token is sold");
        _mintSingleNFT(_tokenId);
    }

    function mintNFT(uint _tokenId) public payable {
        require(_tokenId >= openTokens[0] && _tokenId <= openTokens[1], "Token is closed");

        require(!checkSoldTokens(_tokenId), "Token is sold");

        require(msg.value >= PRICE, "Not enough ether to purchase NFTs.");

        _mintSingleNFT(_tokenId);
    }

    function mintRandomNFT(uint[] memory _tokenIds) public payable {
        uint randomIndex = random(_tokenIds.length);
        uint _tokenId = _tokenIds[randomIndex];

        require(_tokenId >= openTokens[0] && _tokenId <= openTokens[1], "Token is closed");

        require(!checkSoldTokens(_tokenId), "Token is sold");

        require(msg.value >= PRICE_RANDOM, "Not enough ether to purchase NFT.");

        _mintSingleNFT(_tokenId);
    }

    function _mintSingleNFT(uint _tokenId) private {
        _safeMint(msg.sender, _tokenId);
        soldedTokenIds.push(_tokenId);
        emit MintNft(msg.sender, _tokenId);
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
        uint onee = balance * 1 / 2;
        uint twoo = balance * 3 / 10;
        uint thh = balance * 1 / 5;
        require(balance > 0, "No ether left to withdraw");
        (bool success, ) = (address(0x9188848E6dAb144d65537508f32aA5BA2169D4de)).call{value: onee}(""); // app
        (bool successs, ) = (address(0x3e520963A62961ea1Bc9E566204B7181002aB6f9)).call{value: twoo}(""); // ext
        (bool successss, ) = (address(0x9f3B689039644A1a4AA192EDd736ED27685AD5D2)).call{value: thh}(""); // mi
        require(success && successs && successss, "Transfer failed.");
        emit Withdraw(balance, onee, twoo, thh);
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

    function random(uint number) public view returns (uint256){
        uint256 seed = uint256(keccak256(abi.encodePacked(
                block.timestamp + block.difficulty +
                ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)) +
                block.gaslimit +
                ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (block.timestamp)) +
                block.number
            )));

        return (seed - ((seed / number) * number));
    }

    function checkSoldTokens(uint _tokenId) private view returns (bool){
        bool isTokenSold = false;
        for (uint i = 0; i < soldedTokenIds.length; i++) {
            if(soldedTokenIds[i] == _tokenId) {
                isTokenSold = true;
                break;
            }
        }

        return isTokenSold;
    }
}