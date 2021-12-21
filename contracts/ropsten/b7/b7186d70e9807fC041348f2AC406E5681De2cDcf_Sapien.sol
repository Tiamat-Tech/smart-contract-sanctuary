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

    uint256 public MAX_SUPPLY = 5500; // change val before launch
    uint256 public MAX_MINT = 3;
    uint256 public RESERVED = 50;    // amount of sapiens reserved for giveaways
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
    mapping(address => uint256) private minted;
    mapping(address => uint256[]) private reservedList;
    address pubkey = 0x103EcE5B498b9c425295F58148Aa5bdAc7575708;
    address DAO = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    address founder1 = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    address founder2 = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
    address founder3 = 0x617F2E2fD72FD9D5503197092aC168c91465E7f2;
    
    constructor() ERC721("FOMO SAPIENS", "SAPIEN") {}

    function mint(uint256 _numTokens) public payable
    {
        require(!paused);
        require(active, "Sale is currently inactive");
        require(tx.origin == msg.sender, "Contracts are not allowed to mint");
        require(msg.value == (SALE_PRICE * _numTokens), "Incorrect amount of ether");
        require(minted[msg.sender] < MAX_MINT, "You cannot mint more than 3 sapiens from the same address");
        require((minted[msg.sender] + _numTokens) <= MAX_MINT, "You cannot mint more than 3 sapiens");
        require(_tokenIds < (MAX_SUPPLY - RESERVED), "All Sapiens have been minted");
        require((_tokenIds + _numTokens) <= (MAX_SUPPLY - RESERVED), "Purchase would exceed max supply of sapiens");  

        minted[msg.sender] += _numTokens;

        for(uint256 i = 0; i < _numTokens; i++){
            uint256 _tokenId = (_tokenIds + starting_idx) % MAX_SUPPLY + 1;  
            _safeMint(msg.sender, _tokenId);
            _tokenIds++;    
        }        
    }

    function whitelistMint() public payable {
        require(!paused);
        require(presale_active, "Sale is currently inactive");
        require(tx.origin == msg.sender, "Contracts are not allowed to mint");
        //require(isReserved(msg.sender) < MAX_MINT, "You cannot mint more than 3 Sapiens");       
        require(isReserved(msg.sender) != 0,"Sapien needs to be reserved first");

        minted[msg.sender] += reservedList[msg.sender].length;

        for(uint256 i = 0; i < minted[msg.sender]; i++){
            uint256 _tokenId = reservedList[msg.sender][i];  
            _safeMint(msg.sender, _tokenId);
        }
        
    }

    /**
    *   @dev function to set aside tokens for giveaways.
    */
    function sapienReserves() public onlyOwner {
        for(uint256 i = 0; i < RESERVED; i++){
            uint256 _tokenId = (_tokenIds + starting_idx) % MAX_SUPPLY + 1;  
            _safeMint(msg.sender, _tokenId);
            _tokenIds++; 
        }
    }

    /**
    *   @dev function for members to reserve NFT.  Address must be whitelisted to reserve.
    *   @param _signature - used to verify whitelisted address.
    */
    function reserveNFT(bytes calldata _signature, uint256 _numTokens) public payable {
        require(!paused);
        require(presale_active,"Presale is currently inactive");
        require(tx.origin == msg.sender,"Contracts are not allowed to reserve");
        require(isWhitelisted(_signature, msg.sender),"Must be on whitelist to reserve a sapien");
        require(msg.value == (SALE_PRICE * _numTokens),"Incorrect amount of ether");
        require((isReserved(msg.sender) + _numTokens) <= MAX_MINT,"You cannot reserve more than 3 Sapiens");
        require(isReserved(msg.sender) < MAX_MINT,"You can only reserve up to 3 Sapiens from the same address");
        
        // add address to reserved list with reserved tokenIds
        for(uint256 i = 0; i < _numTokens; i++){
            reservedList[msg.sender].push((_tokenIds + starting_idx) % MAX_SUPPLY + 1);
            _tokenIds++;
        }        
    }

    function isReserved(address _user) private view returns (uint256) {
        return reservedList[_user].length;
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
    *   @param _user - address of connected user
    *   @return bool verification
    */
    function isWhitelisted(bytes calldata _signature, address _user) public view returns(bool) {
        return abi.encode(_user,MAX_SUPPLY).toEthSignedMessageHash().recover(_signature) == pubkey;
    }

    function withdraw() public payable onlyOwner {
        // transfer 20% of funds to DAO
        (bool dao,)= payable(DAO).call{value:(address(this).balance * 20 / 100)}("");
        require(dao);

        uint256 remainingBalance = address(this).balance * 33 / 100;
        payable(founder1).transfer(remainingBalance);
        payable(founder2).transfer(remainingBalance);
        payable(founder3).transfer(remainingBalance);

        (bool os,)= payable(DAO).call{value:address(this).balance}("");
        require(os);
    }
}