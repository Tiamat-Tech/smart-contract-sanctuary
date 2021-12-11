// SPDX-License-Identifier: GPL-3.0
// @author SYNDK8
// FOMO SAPIENS NFT Contract

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Sapien is ERC721Enumerable, Ownable{
    using Strings for uint256;
    using ECDSA for bytes32;
    using ECDSA for bytes;

    uint256 public MAX_SUPPLY = 14; // change val before launch
    uint256 public PRESALE_SUPPLY = 6;  // change val before launch
    uint256 private SALE_PRICE = 0.1 ether;
    uint256 public _tokenIds;
    uint256 public starting_idx;
    uint256 public starting_idx_block;
    bool private active = false; // variable for public sale
    bool private presale_active = false; // variable for presale
    bool public paused = false;
    bool public revealed = false;
    string public FSNFT_PROVENANCE = "";
    string public BASE_URL = "ipfs://QmVy1ZWFhg6stX7VSo2XoFopoLqJVT7xc3RWReQ6MXCRMV/";
    string public PLACEHOLDER = "ipfs://QmWnrqkBe9Z1B24H5hooiMMN7z4ZpKRM2N2nNcZPPi7s5r";
    string public EXTENSION = ".json";
    mapping(address => bool) private minted;
    mapping(address => uint256) private reservedList;
    address pubkey = 0x103EcE5B498b9c425295F58148Aa5bdAc7575708;
    address DAO = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    address founder1 = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    address founder2 = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
    address founder3 = 0x617F2E2fD72FD9D5503197092aC168c91465E7f2;
    
    constructor() ERC721("FOMO SAPIENS", "SAPIEN") {}

    function mint() public payable returns(string memory)
    {
        require(!paused);
        // sale must be active
        require(active, "Sale is currently inactive");

        require(tx.origin == msg.sender, "Contracts are not allowed to mint");
    
        // Ether sent must equal the amount of a Sapien
        require(msg.value == SALE_PRICE, "Incorrect amount of ether");

        // Each address is allowed one Sapien
        require(!minted[msg.sender], "You cannot mint more than one Sapien");
        // Tokens minted must not exceed the supply of tokens
        require(totalSupply() < MAX_SUPPLY, "All Sapiens have been minted");  

        uint256 _tokenId = (_tokenIds + starting_idx) % MAX_SUPPLY + 1;  
        
        minted[msg.sender] = true;

        _safeMint(msg.sender, _tokenId);
        string memory _tokenURI = tokenURI(_tokenId);

        _tokenIds++;

        return _tokenURI;
    }

    function whitelistMint() public payable returns(string memory) {
        require(!paused);
        // sale must be active
        require(presale_active, "Sale is currently inactive");

        require(tx.origin == msg.sender, "Contracts are not allowed to mint");

        // Each address is allowed one Sapien
        require(!minted[msg.sender], "You cannot mint more than one Sapien");       

        require(isReserved(msg.sender) != 0,"Sapien needs to be reserved first");
        // Tokens minted must not exceed the supply of tokens
        require(totalSupply() < PRESALE_SUPPLY, "Presale supply has been met");  

        uint256 _tokenId = reservedList[msg.sender];  
        
        minted[msg.sender] = true;

        _safeMint(msg.sender, _tokenId);
        string memory _tokenURI = tokenURI(_tokenId);
    
        return _tokenURI;  
    }

    /**
    *   @dev function to reserve NFT.  Address must be whitelisted to reserve.
    *   @param _signature - used to verify whitelisted address.
    */
    function reserveNFT(bytes calldata _signature) public payable {
        require(!paused);
        require(presale_active,"Presale is currently inactive");
        require(tx.origin == msg.sender,"Contracts are not allowed to reserve");
        //require(isWhitelisted(_signature),"Must be on whitelist to reserve a sapien");
        require(msg.value == SALE_PRICE,"Incorrect amount of ether");
        require(isReserved(msg.sender) == 0,"You can only reserve one Sapien");

        // add address to reserved list with reserved tokenId
        reservedList[msg.sender] = (_tokenIds + starting_idx) % MAX_SUPPLY + 1;
        _tokenIds++;
    }

    function isReserved(address _user) private view returns (uint256) {
        return reservedList[_user];
    }

    /**
    *   @dev function displays placeholder image if not revealed, otherwise displays token image.
    *   @param _tokenId - minted tokenId
    *   @return tokenURI
    */
    function tokenURI(uint256 _tokenId) public view virtual override returns(string memory){
        if(!revealed){
            return PLACEHOLDER;
        }

        return bytes(BASE_URL).length > 0
        ? string(abi.encodePacked(BASE_URL, _tokenId.toString(), EXTENSION)) : "";
    }
    
    function setPublicSale(bool _active) public onlyOwner {
        active = _active;
    }

    function setPresale(bool _active) public onlyOwner {
        presale_active = _active;
    }

    function getPublicSale() public view returns (bool){
        return active;
    }

    function getPresale() public view returns (bool){
        return presale_active;
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function setProvenanceHash(string memory _provenance) public onlyOwner {
        FSNFT_PROVENANCE = _provenance;
        starting_idx_block = block.number;
    }

    function getProvenanceHash() public view returns(string memory) {
        return FSNFT_PROVENANCE;
    }

    /**
    *   @dev function to set the starting index number
    */
    function setStartingIdx() private onlyOwner {
        // cannot change starting index once created
        require(starting_idx == 0,"Starting index has already been set");
        require(starting_idx_block != 0,"Starting block number has not been set");

        starting_idx = uint(blockhash(starting_idx_block)) % MAX_SUPPLY;
    }

    function getStartingIdx() public view returns(uint){
        return starting_idx;
    }

    function setReveal(bool _reveal) public onlyOwner {
        revealed = _reveal;
    }

    /**
    *   @dev function to verify address is whitelisted
    *   @param _signature - used to verify address
    *   @return bool verification
    */
    function isWhitelisted(bytes calldata _signature, address _user) public view returns(address) {
        return _user; //abi.encodePacked(msg.sender,MAX_SUPPLY); //.toEthSignedMessageHash().recover(_signature) == pubkey;
    }

    function withdraw() public payable onlyOwner {
        // transfer 30% of funds to DAO
        (bool dao, ) = payable(DAO).call{value: address(this).balance * 30 / 100}("");
        require(dao);
        // transfer 23.33% of funds to F1
        (bool f1, ) = payable(founder1).call{value: address(this).balance * 23 / 100}("");
        require(f1);
        // transfer 23.33% of funds to F2
        (bool f2, ) = payable(founder2).call{value: address(this).balance * 23 / 100}("");
        require(f2);
        // transfer 23.33% of funds to F3
        (bool f3, ) = payable(founder3).call{value: address(this).balance * 23 / 100}("");
        require(f3);
        // transfer remaining funds to DAO
        (bool os, ) = payable(DAO).call{value: address(this).balance}("");
        require(os);
    }
}