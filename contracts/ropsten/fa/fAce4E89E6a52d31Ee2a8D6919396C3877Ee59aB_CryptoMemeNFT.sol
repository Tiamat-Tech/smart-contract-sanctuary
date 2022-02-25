// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";


contract CryptoMemeNFT is ERC721URIStorage, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter tokenIds;
    Counters.Counter availableTokensCounter;

    using Address for address;

    event MintCounter(uint256 mintedCounter);
    event Minted(string tokenURI);


    // Starting and stopping sale, presale and whitelist
    bool public saleActive = false;
    bool public whitelistActive = false;

    // Reserved for the team, customs, giveaways, collabs and so on.
    uint256 public reserved = 50;

    // Price of each token
    uint256 public price = 0.1 ether;

    // Minted Counter and Available Counter
    uint256 public mintedCounter;
    uint256 public availableCounter;

    // Reveal booleans
    bool public revealed = false;

    // Maximum limit of tokens that can ever exist
    uint256 public constant MAX_MINT_PER_TX = 3;

    // The base link that leads to the image / video of the token
    string public baseTokenURI = "https://gateway.pinata.cloud/ipfs/";
    string public hiddenTokenURI = "https://gateway.pinata.cloud/ipfs/QmanJtyGy3XTVRXfA2mCqK29WezkX9UF6rasaxwrrY8rtL/hidden";


    // Team addresses for withdrawals
    address public a1;
    address public a2;
    address public a3;
    address public a4;

    struct Whitelist {
        uint256 amount;
        bool active;
    }
    // List of addresses that have a number of reserved tokens for whitelist
    mapping (address => Whitelist) private whitelistReserved;


    struct Token {
        bool active;
        string tokenURI;
    }
    // Token Mappings
    mapping (uint256 => Token) private availableTokens;
    mapping (string => uint256) private availableTokenSearch;
    mapping (uint256 => Token) private mintedTokens;
    mapping (string => uint256) private mintedTokenSearch;


    constructor () ERC721 ("Crypto Memez", "CMZ") {}


    function tokenURI(uint256 _tokenId) public view override(ERC721URIStorage) returns(string memory){
        if(revealed && mintedTokens[_tokenId].active) {
            return string(abi.encodePacked(baseTokenURI, mintedTokens[_tokenId].tokenURI));
        }
        return hiddenTokenURI;
    }

    // Override so the openzeppelin tokenURI() method will use this method to create the full tokenURI instead
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    // Exclusive whitelist minting
    function mintWhitelist(uint256 _amount) external payable {
        uint256 reservedAmt = whitelistReserved[msg.sender].amount;
        require( whitelistActive,                                   "Whitelist isn't active" );
        require( whitelistReserved[msg.sender].active,              "address is not whitelisted" );
        require( reservedAmt > 0,                                   "No tokens reserved for your address" );
        require( _amount <= reservedAmt,                            "Can't mint more than reserved" );
        require(_amount + mintedCounter <= availableTokensCounter.current(), "Cant' mint more than available" );
        require( msg.value == price * _amount,                      "Wrong amount of ETH sent" );
        whitelistReserved[msg.sender].amount = reservedAmt - _amount;
        for(uint256 i; i < _amount; i++){
            tokenIds.increment();
            uint256 _newId = tokenIds.current();
            string memory _tokenURI = availableTokens[_newId].tokenURI;
            require(mintedTokenSearch[_tokenURI] == 0, "token already minted");
            _safeMint( msg.sender, _newId);
            _setTokenURI(_newId, _tokenURI);
            // setting minted token struc;
            mintedTokens[_newId].tokenURI = _tokenURI;
            mintedTokens[_newId].active = true;
            // update search
            mintedTokenSearch[_tokenURI] = 1;
            mintedCounter++;
            emit MintCounter(mintedCounter);
            emit Minted(_tokenURI);
        }
    }

    // Standard mint function
    function mintToken(uint256 _amount) external payable{
        require( saleActive,                                        "Sale isn't active" );
        require( _amount > 0 && _amount <= MAX_MINT_PER_TX,         "exceeded max mint per transaction");
        require( msg.value == price * _amount,                      "Wrong amount of ETH sent" );
        require(_amount + mintedCounter <= availableTokensCounter.current(),  "Cant' mint more than available" );
    for(uint256 i; i < _amount; i++){
            tokenIds.increment();
            uint256 _newId = tokenIds.current();
            string memory _tokenURI = availableTokens[_newId].tokenURI;
            require(mintedTokenSearch[_tokenURI] == 0, "token already minted");
            _safeMint( msg.sender, _newId);
            _setTokenURI(_newId, _tokenURI);
            // setting minted token struc;
            mintedTokens[_newId].tokenURI = _tokenURI;
            mintedTokens[_newId].active = true;
            // update search
            mintedTokenSearch[_tokenURI] = 1;
            mintedCounter++;
            emit MintCounter(mintedCounter);
            emit Minted(_tokenURI);
        }
    }

    // Admin minting function to reserve tokens for the team, collabs, customs and giveaways
    function mintReserved(uint256 _amount) external onlyOwner {
        // Limited to a publicly set amount
        require( _amount <= reserved, "Can't reserve more than set amount" );
        reserved -= _amount;
        for(uint256 i; i < _amount; i++){
            tokenIds.increment();
            uint256 _newId = tokenIds.current();
            string memory _tokenURI = availableTokens[_newId].tokenURI;
            require(mintedTokenSearch[_tokenURI] == 0, "token already minted");
            _safeMint( msg.sender, _newId);
            _setTokenURI(_newId, _tokenURI);
            // setting minted token struc;
            mintedTokens[_newId].tokenURI = _tokenURI;
            mintedTokens[_newId].active = true;
            // update search
            mintedTokenSearch[_tokenURI] = 1;
            mintedCounter++;
            emit Minted(_tokenURI);
        }
    }

    // Edit reserved whitelist spots
    //[address1, address2], [amount1, amount2], [true, true]
    function editWhitelistReserved(address[] memory _a, uint256[] memory _amount, bool[] memory _active) external onlyOwner {
        for(uint256 i; i < _a.length; i++){
            whitelistReserved[_a[i]].active = _active[i];
            whitelistReserved[_a[i]].amount = _amount[i];
        }
    }

    // Start and stop whitelist
    function setWhitelistActive(bool val) external onlyOwner {
        whitelistActive = val;
    }

    // Start and stop sale
    function setSaleActive(bool val) external onlyOwner {
        saleActive = val;
    }

    // Set new baseURI
    function setBaseURI(string memory baseURI) external onlyOwner {
        baseTokenURI = baseURI;
    }

    // Set a different price silver tokens
    function setPrice(uint256 _newPrice) external onlyOwner {
        price = _newPrice;
    }

    // Set team addresses
    function setAddresses(address[] memory _a) external onlyOwner {
        a1 = _a[0];
        a2 = _a[1];
        a3 = _a[2];
        a4 = _a[3];
    }

    // Withdraw funds from contract for the team
    function withdrawTeam(uint256 amount) external payable onlyOwner {
        uint256 percent = amount / 100;
        require(payable(a1).send(percent * 25));
        require(payable(a2).send(percent * 25));
        require(payable(a3).send(percent * 25));
        require(payable(a4).send(percent * 25));
    }

    function addAvailableTokens(string[] memory _tokens) external onlyOwner {

        for(uint256 i; i < _tokens.length; i++){
            require(availableTokenSearch[_tokens[i]] == 0, "token already added");
            availableTokensCounter.increment();
            uint256 _id = availableTokensCounter.current();
            availableTokens[_id].tokenURI = _tokens[i];
            availableTokens[_id].active = true;
            availableTokenSearch[_tokens[i]] = 1;
            availableCounter++;
        }
    }

    function getContractBalance() external onlyOwner view returns(uint256){
        return address(this).balance;
    }

    function isAddressInWhitelist() external view returns(bool) {
        return whitelistReserved[msg.sender].active;
    }

    function setReveal (bool reveal) external onlyOwner {
        revealed = reveal;
    }

    function getAvailableTokens () external onlyOwner view returns(string[] memory) {
        string[] memory _tokens = new string[](availableTokensCounter.current());
        for (uint256 i; i < availableTokensCounter.current(); i++){
            _tokens[i] = availableTokens[i+1].tokenURI;
        }
        return _tokens;
    }

    function getAddressAvailableWhitelistAmount () external view returns(uint256){
        return whitelistReserved[msg.sender].amount;
    }
}