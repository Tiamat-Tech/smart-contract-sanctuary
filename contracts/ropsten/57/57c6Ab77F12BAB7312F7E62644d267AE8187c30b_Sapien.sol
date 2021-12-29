// SPDX-License-Identifier: GPL-3.0
// @author SYNDK8
// FOMO SAPIENS NFT Contract

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Sapien is ERC721, Ownable{
    using Strings for uint256;
    using ECDSA for bytes32;
    using ECDSA for bytes;

    uint256 public MAX_SUPPLY = 20; // change val before launch
    uint256 public MAX_MINT = 3;
    uint256 public GIVEAWAYS = 3;    // amount of sapiens reserved for giveaways
    uint256 private SALE_PRICE = 0.1 ether;
    uint256 public _tokenIds;
    uint256 public starting_idx;
    uint256 private starting_block_num;
    bool public active = false; // variable for public sale
    bool public presale_active = false; // variable for presale
    bool public paused = false;
    bool public revealed = false;
    string public FSNFT_PROVENANCE;
    string public BASE_URL;
    bytes32 public EXTENSION = ".json";
    mapping(address => uint256) private minted;
    address pubkey = 0x103EcE5B498b9c425295F58148Aa5bdAc7575708;
    address DAO = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    address founder1 = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    address founder2 = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
    address founder3 = 0x617F2E2fD72FD9D5503197092aC168c91465E7f2;
    
    constructor() ERC721("FOMO SAPIENS", "SAPIEN") {}

    function mint(uint256 tokensToMint) public payable
    {
        require(!paused);
        require(active, "Sale is currently inactive");
        require(tx.origin == msg.sender, "Contracts are not allowed to mint");
        require(msg.value == (SALE_PRICE * tokensToMint), "Incorrect amount of ether");
        require(_tokenIds < (MAX_SUPPLY - GIVEAWAYS), "All Sapiens have been minted");
        require((_tokenIds + tokensToMint) <= (MAX_SUPPLY - GIVEAWAYS), "Purchase would exceed max supply of sapiens"); 
        require(minted[msg.sender] < MAX_MINT, "You cannot mint more than 3 sapiens from the same address");
        require((minted[msg.sender] + tokensToMint) <= MAX_MINT, "You cannot mint more than 3 sapiens");
         
        minted[msg.sender] += tokensToMint;

        for(uint256 i = 0; i < tokensToMint; i++){ 
            _mint(msg.sender, getInitialSequence());
            _tokenIds++;    
        }        
    }

    /**
    *   @dev function to set aside tokens for giveaways.
    */
    function mintGiveaways() public onlyOwner {
        for(uint256 i = 0; i < GIVEAWAYS; i++){ 
            _mint(msg.sender, getInitialSequence());
            _tokenIds++; 
        }
    }

    /**
    *   @dev function for members to reserve sapiens.  Address must be whitelisted to reserve.
    *   @param _signature - used to verify whitelisted address.
    */
    function whitelistMint(bytes calldata _signature, uint256 tokensToMint) public payable {
        require(!paused);
        require(presale_active,"Presale is currently inactive");
        require(tx.origin == msg.sender,"Contracts are not allowed to mint");
        require(isWhitelisted(_signature, msg.sender),"Must be on whitelist to mint a sapien");
        require(msg.value == (SALE_PRICE * tokensToMint),"Incorrect amount of ether");
        require((minted[msg.sender] + tokensToMint) <= MAX_MINT,"You cannot mint more than 3 Sapiens");
        require(minted[msg.sender] < MAX_MINT,"You can only mint up to 3 Sapiens from the same address");
        
        minted[msg.sender] += tokensToMint;

        for(uint256 i = 0; i < tokensToMint; i++){ 
            _mint(msg.sender, getInitialSequence());
            _tokenIds++;    
        }     
    }

    /**
    *   @dev function displays placeholder image if not revealed, otherwise displays token image.
    *   @param _tokenId - minted tokenId
    *   @return tokenURI
    */
    function tokenURI(uint256 _tokenId) public view virtual override returns(string memory){
        if(!revealed){
            return BASE_URL;
        }

        return string(abi.encodePacked(BASE_URL, _tokenId.toString(), EXTENSION));
    }

    function getInitialSequence() private view returns (uint256){
        return (_tokenIds + starting_idx) % MAX_SUPPLY + 1;
    }
    
    function setPublicSale(bool _active) public onlyOwner {
        active = _active;
    }

    function setPresale(bool _active) public onlyOwner {
        presale_active = _active;
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function setProvenanceHash(string memory _provenance) public onlyOwner {
        require(starting_block_num == 0,"Provenance has already been set");

        FSNFT_PROVENANCE = _provenance;
        starting_block_num = block.number;
    }

    function setStartingIdx() public onlyOwner {
        require(starting_idx == 0,"Starting index has already been set");

        starting_idx = uint(blockhash(starting_block_num)) % MAX_SUPPLY;
    }

    function toggleReveal(string memory _url) public onlyOwner {
        BASE_URL = _url;
        revealed = !revealed;
    }

    function setBaseURL(string memory _url) public onlyOwner {
        BASE_URL = _url;
    }

    function getMinted(address _user) public view onlyOwner returns(uint256) {
        return minted[_user];
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