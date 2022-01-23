pragma solidity ^0.8.11;
// SPDX-License-Identifier: MIT
/// @title X
/// @author [email protected]
/// @dev Z

// We are artists, developers, and artificial intelligence scientists.
// The contents herein outline the terms for the Szzz collection:
// Tokens in this contract will only be minted by G R LLC, and will made available through chosen brokers for the maximum token count of 15,000.
// Tokens will be made available in random drops  until the maximum token count is hit.
// G R reserves the right to withhold tokens for G R LLC company investments.
// The Ethereum block-chain is public and outside of G R's direct sphere of influence.

//All artwork within the Szzz collection; Copyright© 2022, GR, LLC, All rights reserved. Learn more about our Szzz collection at GR.com and Szzz.io.





import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract Stuff is ERC721Enumerable, Ownable {
    using Address for address;
    using Strings for uint256;

    // Starting and stopping sale and presale
    bool public saleActive = false;
    bool public presaleActive = false;

    // Reserved
    uint256 public reserved = 250;

    // Price of each token
    uint256 public price = 0.01 ether;

    // Maximum limit of tokens that can ever exist
    uint256 constant MAX_SUPPLY = 25000;

    uint256 public constant MAX_PER_ADDRESS_PRESALE = 5;
    uint256 public constant MAX_PER_ADDRESS_PUBLIC = 10;

    // The base link that leads to the image / video of the token
    // string public baseTokenURI; A

    // whitelist for presale
    mapping(address => bool) public whitelisted;

    // string public baseExtension = ".json"; A
    // bool public revealed = false; A
    // string public notRevealedUri; A

    // Team addresses for withdrawals
    address public Account1 = 0x4f0489032Fb035e32Cf28e6BE850C3a5D6D2Df3F;
    address public Account2 = 0x85809e4323fa587ac31eaf485b065a6C636a9d1c;
    address public Account3 = 0x860C4f4E340F63Ccb9560E8b5438eA14254E73d9;
    address public Archive = 0xFd3453910d5475124E040f0A17D2128B36907A39;

    // Base URI
    string private _baseURIextended = "ipfs://";
    constructor() ERC721("Stuff", "STF") {}

    // See which address owns which tokens
    function tokensOfOwner(address addr) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(addr);
        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(addr, i);
        }
        return tokensId;
    }

    // mint function
    function mint(uint256 _amount) public payable {
        uint256 supply = totalSupply();
        if (presaleActive) {
            require(whitelisted[msg.sender] == true, "Not presale member");
            require( _amount > 0 && _amount <= MAX_PER_ADDRESS_PRESALE,    "Can only mint between 1 and 3 tokens at once" );
            require( supply + _amount <= MAX_SUPPLY, "Can't mint more than max supply" );
            require(balanceOf(msg.sender) + _amount <= MAX_PER_ADDRESS_PRESALE, "Can only mint up to 3 tokens per wallet");
            require( msg.value == price * _amount,   "Wrong amount of ETH sent" );
            for(uint256 i; i < _amount; i++){
                _safeMint( msg.sender, supply + i + 1 ); // Token id starts from 1
            }
        } else {
            if (saleActive) {
                require( _amount > 0 && _amount <= MAX_PER_ADDRESS_PUBLIC,    "Can only mint between 1 and 10 tokens at once" );
                require( supply + _amount <= MAX_SUPPLY, "Can't mint more than max supply" );
                require(balanceOf(msg.sender) + _amount <= MAX_PER_ADDRESS_PUBLIC, "Can only mint up to 10 tokens per wallet");
                require( msg.value == price * _amount,   "Wrong amount of ETH sent" );
                for(uint256 i; i < _amount; i++){
                    _safeMint( msg.sender, supply + i + 1); // Token id starts from 1
                }
            } else {
                require( presaleActive,                  "Presale isn't active" );
                require( saleActive,                     "Sale isn't active" );
            }
        }
    }

    // Admin minting function to reserve tokens for the team, collabs, customs and giveaways
    // ? // only a certain Address can mint this ... owner is option as well
    function mintReserved(uint256 _amount) public  {
        require( msg.sender == Archive, "Don't have permission to mint" );
        // Limited to a publicly set amount
        require( _amount <= reserved, "Can't reserve more than set amount" );
        reserved -= _amount;
        uint256 supply = totalSupply();
        for(uint256 i; i < _amount; i++){
            _safeMint( msg.sender, supply + i + 1); // Token id starts from 1
        }
    }

    // Start and stop presale
    function setPresaleActive(bool val) public onlyOwner {
        presaleActive = val;
    }

    // Start and stop sale
    function setSaleActive(bool val) public onlyOwner {
        saleActive = val;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseURIextended = baseURI_;
    }
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }


    // Set a different price in case ETH changes drastically
    function setPrice(uint256 newPrice) public onlyOwner {
        price = newPrice;
    }

    // add user's address to whitelist for presale
    function addWhitelistUser(address[] memory _user) public onlyOwner {
        for(uint256 idx = 0; idx < _user.length; idx++) {
            require(whitelisted[_user[idx]] == false, "already set");
            whitelisted[_user[idx]] = true;
        }
    }

    // remove user's address to whitelist for presale
    function removeWhitelistUser(address[] memory _user) public onlyOwner {
        for(uint256 idx = 0; idx < _user.length; idx++) {
            require(whitelisted[_user[idx]] == true, "not exist");
            whitelisted[_user[idx]] = false;
        }
    }


    // withdraw all amount from contract
    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "There is no balance to withdraw");
        uint256 percent = balance / 100;
        _widthdraw(Account1, percent * 100/3);
        _widthdraw(Account2, percent * 100/3);
        _widthdraw(Account3, percent * 100/3);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }
}