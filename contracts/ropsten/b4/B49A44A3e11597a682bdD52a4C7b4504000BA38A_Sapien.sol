// SPDX-License-Identifier: GPL-3.0
// @author SYNDK8
// FOMO SAPIENS NFT Contract

pragma solidity >=0.7.0 <0.9.0;

import "./ERC721S.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Sapien is ERC721S, Ownable{
    using Strings for uint256;
    using ECDSA for bytes32;
    using ECDSA for bytes;

    struct Config {
        bool active;
        bool presale_active;
        bool paused;
        bool revealed;
        uint16 starting_idx;
        uint16 _tokenIds;
        uint16 max_supply;
        uint16 max_mint;
        uint16 GIVEAWAYS;     
    }

    uint256 SALE_PRICE = 0.1 ether;
    string BASE_URL;
    string FSNFT_PROVENANCE;
    uint256 private starting_block_num;    
    bytes32 public EXTENSION = ".json";
    mapping(address => uint256) private minted;
    Config public config;
    address pubkey = 0x103EcE5B498b9c425295F58148Aa5bdAc7575708;
    address DAO = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    address founder1 = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    address founder2 = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
    address founder3 = 0x617F2E2fD72FD9D5503197092aC168c91465E7f2;      
    
    constructor() ERC721S("FOMO SAPIENS NFT", "SAPIEN", 6000, 5) {
        config.max_supply = 6000;
        config.max_mint = 5;
        config.GIVEAWAYS = 30;
    }

    /*
    *   @dev public mint method
    *   @param - number of NFT's to mint
    *   
    *   Assumes quantity does not excede 2 ** 16 - 1
    */
    function mint(uint16 quantity) public payable
    {
        uint16 ids = config._tokenIds;

        require(config.active, "Sale is currently inactive");
        require(tx.origin == msg.sender, "Contracts are not allowed to mint");
        require(msg.value == (SALE_PRICE * quantity), "Incorrect amount of ether");
        require((ids + quantity) <= config.max_supply, "Purchase would exceed max supply of sapiens"); 
        require((balanceOf(msg.sender) + quantity) <= config.max_mint, "You cannot mint more than 3 sapiens from the same address");
        require(quantity <= config.max_mint, "You cannot mint more than 3 sapiens");
         
        _mint(msg.sender, quantity);
        config._tokenIds = ids + quantity;     
    }

    /**
    *   @dev function to set aside tokens for giveaways.
    */
    function devMint() public onlyOwner {

        uint256 num_batch = config.GIVEAWAYS / config.max_mint;

        for(uint256 i = 0; i < num_batch; i++){ 
            _mint(msg.sender, config.max_mint);
        }

        config._tokenIds += config.GIVEAWAYS;
    }

    /**
    *   @dev mint function for users who are whitelisted.  Address must be whitelisted.
    *   @param _signature - used to verify whitelisted address.
    *   @param quantity - number of NFT's to mint
    * 
    *   Assumes quantity does not exceed 2 ** 16 - 1
    */
    function whitelistMint(bytes calldata _signature, uint16 quantity) public payable {
        
        require(config.presale_active,"Presale is currently inactive");
        require(tx.origin == msg.sender,"Contracts are not allowed to mint");
        require(isWhitelisted(_signature, msg.sender),"Must be on whitelist to mint a sapien");
        require(msg.value == (SALE_PRICE * quantity),"Incorrect amount of ether");
        require(quantity <= config.max_mint,"You cannot mint more than 3 Sapiens");
        require(minted[msg.sender] < config.max_mint,"You can only mint up to 3 Sapiens from the same address");
        
        minted[msg.sender] += quantity;
        _mint(msg.sender, quantity);
        config._tokenIds += quantity;
    }

    /**
    *   @dev method used to display metadata
    *   @param _tokenId - minted tokenId
    *   @return tokenURI
    */
    function tokenURI(uint256 _tokenId) public view virtual override returns(string memory){
        return !config.revealed ? BASE_URL : string(abi.encodePacked(BASE_URL, _tokenId.toString(), EXTENSION));
    }
    
    function setPublicSale() public onlyOwner {
        config.active = !config.active;
    }

    function setPresale() public onlyOwner {
        config.presale_active = !config.presale_active;
    }

    function setPaused() public onlyOwner {
        config.paused = !config.paused;
    }

    function setProvenanceHash(string memory _provenance) public onlyOwner {
        require(starting_block_num == 0,"Provenance has already been set");

        FSNFT_PROVENANCE = _provenance;
        starting_block_num = block.number;
    }

    /*
    *   @dev method to get token based on starting index
    *   
    *   starting_idx must be set.
    */
    function getInitialSequence() internal override view returns (uint16){
        return (config._tokenIds + config.starting_idx) % config.max_supply + 1;
    }

    /*
    *   @dev override method of {ERC721 _exists} optimized for batch mint with initial sequence.
    *   
    */
    function _exists(uint16 tokenId) internal view override returns (bool) {
        uint16 start_idx = config.starting_idx;

        if(tokenId > 0 && tokenId <= config.max_supply){
            if(tokenId < start_idx){
                return tokenId + config.max_supply - start_idx <= config._tokenIds;
            }

            return tokenId - start_idx <= config._tokenIds;
        }

        return false;
    }

    function setStartingIdx() public onlyOwner {
        _setStartingIdx(starting_block_num);
    }

    function _setStartingIdx(uint256 starting_block) internal virtual {
        require(config.starting_idx == 0,"Starting index has already been set");

        config.starting_idx = uint16(uint256(blockhash(starting_block)) % config.max_supply);
    }

    function toggleReveal(string memory _url) public onlyOwner {
        BASE_URL = _url;
        config.revealed = !config.revealed;
    }

    function totalSupply() public view returns (uint16) {
        return config._tokenIds;
    }

    function getMaxMint() public view returns (uint16) {
        return config.max_mint;
    }

    function getMaxSupply() public view returns (uint16){
        return config.max_supply;
    }

    function publicSaleActive() public view returns (bool) {
        return config.active;
    }

    function presaleActive() public view returns (bool) {
        return config.presale_active;
    }

    function setBaseURL(string memory _url) public onlyOwner {
        BASE_URL = _url;
    }

    /**
    *   @dev function to verify address is whitelisted
    *   @param _signature - used to verify address
    *   @param _user - address of connected user
    *   @return bool verification
    */
    function isWhitelisted(bytes calldata _signature, address _user) public view returns(bool) {
        return abi.encode(_user,config.max_supply).toEthSignedMessageHash().recover(_signature) == pubkey;
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