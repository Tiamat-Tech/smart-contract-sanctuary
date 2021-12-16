// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "hardhat/console.sol";

//contract UnknownNFT is Ownable, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, ERC721Pausable {
//contract UnknownNFT is Ownable, ERC721Enumerable, ERC721URIStorage, ERC721Burnable {
contract UnknownNFT is Ownable, ERC721Enumerable, ERC721Burnable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    enum State {
        NOSALE,
        PRESALE,
        PUBLICSALE
    }

    State public state = State.NOSALE;

    string internal baseURI;

    string public provenance;

    Counters.Counter private _tokenIdCounter;

    uint256 public mintPrice = 0.06 ether;

    uint256 public maxTokenSupply = 10000;

    uint256 public constant maxMintPerTXs = 10;

    uint256 public maxPresaleMintPerWallet = 8;
    
    mapping (address => bool) private _presaleWhitelist;
    mapping (address => uint256) private _presaleMinted;     // set 999 
    uint256 public presaleStartTime;
    uint256 public presaleEndTime;

    event EventWithdraw(address to, uint256 amount);



    constructor(uint256 maxSupply, uint256 price) ERC721("UnknownNFT", "UNFT") {
        maxTokenSupply = maxSupply;
        mintPrice = price;
    }

    function setMaxTokenSupply(uint256 _maxTokenSupply) public onlyOwner {
        maxTokenSupply = _maxTokenSupply;
    }
    
    function getMaxTokenSupply() public view returns (uint256) {
        return maxTokenSupply;
    }

    function getMintPrice() public view returns (uint256) {
        return mintPrice;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    //function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
    function tokenURI(uint256 tokenId) public view virtual override(ERC721) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    //function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
    function _burn(uint256 tokenId) internal virtual override(ERC721) {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    //) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /*     
    * Set provenance once it's calculated
    */
    function setProvenanceHash(string memory _provenanceHash) public onlyOwner {
        provenance = _provenanceHash;
    }

    function addPresaleAddress(address _addr) public onlyOwner {
        _presaleWhitelist[_addr] = true;
    }

    function addPresaleAddresses(address[] calldata addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _presaleWhitelist[addresses[i]] = true;
        }
    }

    function isInPresaleWhitelist(address presaleAddress) public view returns (bool) {
        return _presaleWhitelist[presaleAddress];
    }

    function StartPresale(uint256 _startTime, uint256 _endTime) public onlyOwner {
        state = State.PRESALE;
        presaleStartTime = _startTime;
        presaleEndTime = _endTime;

        console.log(block.timestamp);
    }

    function EndSale() public onlyOwner {
        state = State.NOSALE;
    }

    function PublicSale() public onlyOwner {
        state = State.PUBLICSALE;
    }

    function getState() public view returns(State) {
        return state;
    }

    /*
    * Mint reserved NFTs for giveaways, dev, etc.
    */
    function reserveMint(uint256 reservedAmount, address mintAddress) public onlyOwner {
        require(totalSupply() + reservedAmount <= maxTokenSupply, "Purchase would exceed max available NFTs");
        uint256 supply = _tokenIdCounter.current();
        for (uint256 i = 1; i <= reservedAmount; i++) {
            _safeMint(mintAddress, supply + i);
            _tokenIdCounter.increment();
        }
    }

    /*
    * Mint NFTs during pre-sale
    */
    function presaleMint(uint256 numberOfTokens) public payable {
        console.log(msg.sender);
        console.log("blocktime:", block.timestamp);
        require(state == State.PRESALE, "It is not in presale state");
        require(block.timestamp >= presaleStartTime, "Pre-sale is not live yet");
        require(block.timestamp <= presaleEndTime, "Pre-sale is over");
        require(_presaleWhitelist[_msgSender()] == true, "Not in presale whitelist");
        require(_presaleMinted[_msgSender()] + numberOfTokens <= maxPresaleMintPerWallet, "Max presale mints per wallet limit exceeded");
        require(totalSupply() + numberOfTokens <= maxTokenSupply, "Soldout");
        require(mintPrice * numberOfTokens == msg.value, "Ether value sent is not correct");

        _presaleMinted[msg.sender] += numberOfTokens;

        for(uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = _tokenIdCounter.current() + 1;
            if (mintIndex <= maxTokenSupply) {
                _tokenIdCounter.increment();
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    /*
    * Mint unknown NFTs
    */
    function mint(uint256 numberOfTokens) public payable {
        require(state == State.PUBLICSALE, "It is not in public state");
        require(numberOfTokens <= maxMintPerTXs, "You can mint a max of 15 RL NFTs at a time");
        require(totalSupply() + numberOfTokens <= maxTokenSupply, "Soldout");
        require(mintPrice * numberOfTokens <= msg.value, "Ether value sent is not correct");

        for(uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = _tokenIdCounter.current() + 1;
            if (mintIndex <= maxTokenSupply) {
                _tokenIdCounter.increment();
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(_msgSender()), balance);
    }

    function withdraw(uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");

        Address.sendValue(payable(_msgSender()), amount);
        //emit PaymentReleased(_msgSender(), amount);
    }
}