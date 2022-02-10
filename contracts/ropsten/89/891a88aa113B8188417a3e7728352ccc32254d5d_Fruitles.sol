// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721Enum.sol";


contract Fruitles is ERC721Enum, Ownable, PaymentSplitter, Pausable,  ReentrancyGuard {
    using Strings for uint256;
    string public baseURI = "ipfs://QmNqgfoAsuHbPp4BqCz48mpDqSvYu7UhYaaEzQ8mM7ZWz8/";

    //sale settings
    uint256 public cost = 0.05 ether;
    uint256 public maxSupply = 6666;
    uint256 public maxMint = 7;
    bool public presaleActive = false;
    bool public publicSaleActive = false;

    //presale settings
    mapping(address => uint256) public presaleWhitelist;

    //share settings
    address[] private addressList = [0x69EdEDBc410758c9B7C6dF712fB007584c3c89a6];

    uint[] private shareList = [100];

    constructor() ERC721P("Fruitles", "FRU") PaymentSplitter(addressList, shareList){}

    function _baseURI() internal view virtual returns (string memory) {
        return baseURI;
    }

    // public minting
    function mint(uint256 _mintAmount) public payable nonReentrant{
        uint256 s = totalSupply();
        require(publicSaleActive, "");
        require(_mintAmount > 0, "" );
        require(_mintAmount <= maxMint, "" );
        require(s + _mintAmount <= maxSupply, "" );
        require(cost * _mintAmount == msg.value, "");
        for (uint256 i = 0; i < _mintAmount; ++i) {
            _safeMint(msg.sender, s + i, "");
        }
        delete s;
    }

    // presale minting
    function mintPresale(uint256 _mintAmount) public payable {
        uint256 s = totalSupply();
        uint256 reserve = presaleWhitelist[msg.sender];
        require(_mintAmount > 0, "0" );
        require(presaleActive, "");
        require(reserve > 0, "");
        require(_mintAmount <= reserve, "");
        require(s + _mintAmount <= maxSupply, "");
        require(cost * _mintAmount == msg.value, "");
        presaleWhitelist[msg.sender] = reserve - _mintAmount;
        delete reserve;
        for(uint256 i; i < _mintAmount; i++){
            _safeMint(msg.sender, s + i, "");
        }
        delete s;
    }

    // admin minting
    function gift(uint[] calldata quantity, address[] calldata recipient) external onlyOwner{
        require(quantity.length == recipient.length, "Provide quantities and recipients" );
        uint totalQuantity = 0;
        uint256 s = totalSupply();
        for(uint i = 0; i < quantity.length; ++i){
            totalQuantity += quantity[i];
        }
        require(s + totalQuantity <= maxSupply, "Cant go over supply");
        delete totalQuantity;
        for(uint i = 0; i < recipient.length; ++i){
            for(uint j = 0; j < quantity[i]; ++j){
            _safeMint( recipient[i], s++, "" );
            }
        }
        delete s;
    }

	// admin functionality
	function presaleSet(address[] calldata _addresses, uint256[] calldata _amounts) public onlyOwner {
        for(uint256 i; i < _addresses.length; i++){
            presaleWhitelist[_addresses[i]] = _amounts[i];
	    }
    }
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString())) : "";
    }
	function setCost(uint256 _newCost) public onlyOwner {
	    cost = _newCost;
	}
	function setMaxMint(uint256 _newmaxMint) public onlyOwner {
	    maxMint = _newmaxMint;
	}
	function setMaxSupply(uint256 _newMaxSupply) public onlyOwner {
	    maxSupply = _newMaxSupply;
	}
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }
    function setPresaleSaleStatus(bool _status) public onlyOwner {
        presaleActive = _status;
    }
    function setPublicSaleStatus(bool _status) public onlyOwner {
        publicSaleActive = _status;
    }
    function withdraw() public payable onlyOwner {
    (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
    require(success);
    }
    function withdrawSplit() public onlyOwner {
        for (uint256 sh = 0; sh < addressList.length; sh++) {
            address payable wallet = payable(addressList[sh]);
            release(wallet);
        }
    }
}