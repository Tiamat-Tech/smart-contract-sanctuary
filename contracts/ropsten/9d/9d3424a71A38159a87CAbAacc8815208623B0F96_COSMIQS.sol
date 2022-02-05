// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";


contract COSMIQS is ERC721A, Ownable, PaymentSplitter  {
   
    using Strings for uint256;

    //Settings

    string private baseURI;
    string private hiddenURI;
    string private URIextension = ".json";
    uint256 public constant maxSupply = 8000;  //First [number] will be auctioned off for charity. Dev mint [number] will be minted for giveaways and partnetships.
    uint256 private mintPrice = 0.2 ether;
    uint256 public whitelistMaxMint = 2;
    bool public revealed = false;
    bool public paused = true;
    bool private hasWhitelist = true;
    address[] private onWhitelist;


    //Equity
    address[] payees = [0xE27F3Ad806Da50A1bF7E679ed72428B2b8412725,
    0x0Be6caEbEDCc1bCc23741496Ea83b4e995E068BF];
    uint256[] shares_ = [25,
    75];


    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        string memory _initHiddenURI
    ) ERC721A(_name, _symbol) PaymentSplitter(payees, shares_) {
        setURI(_initBaseURI);
        setHiddenURI(_initHiddenURI);
    }
    
    //Minting functionality
    function mintCosmiq(uint256 _tokenAmount) public payable {
        uint256 supply = totalSupply();

        require(paused == false, "Sale is not active!");
        require(_tokenAmount > 0, "Can't mint zero!");
        require(supply + _tokenAmount <= maxSupply, "Would exceed maximum supply, mint less!");
        
        if (msg.sender != owner()) {
          if(hasWhitelist == true) {
                require(isWhitelisted(msg.sender), "Not on Whitelist!");
                uint256 addrMinted = balanceOf(msg.sender);
                require(addrMinted < whitelistMaxMint, "Would exceed whitelist max mint!");
            } 
        require(msg.value == mintPrice * _tokenAmount, "Wrong ETH amount!");
        }

        _safeMint(msg.sender, _tokenAmount);
    }


    //WL+PreSale setting
    function whitelistUsers(address[] calldata _addresses) public onlyOwner {
        onWhitelist = _addresses;
    }

    function isWhitelisted(address _user) public view returns (bool) {
        for(uint256 i = 0; i < onWhitelist.length; i++) {
            if (onWhitelist[i] == _user) {
                return true;
            }
        }
        return false;
    }

    //Metadata
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Nonexistent token query!");
        if(revealed == false) {
            return hiddenURI;
        }
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), URIextension)) : "";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
  }
    
    function setURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setHiddenURI(string memory _hiddenURI) public onlyOwner {
        hiddenURI = _hiddenURI;
    }
    
    function revealNFT() public onlyOwner() {
        revealed = true;
    }


    //Sale State
    //If true, WL is active, if false public sale is active.
    function setWhitelistActive(bool _wlactive) public onlyOwner {
        hasWhitelist = _wlactive;
    }
    function isPaused(bool _paused) public onlyOwner {
        paused = _paused;
    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }
}