// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";


contract ArrLandNFT is ERC721Upgradeable, OwnableUpgradeable {
    using StringsUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;

    uint256 public MAX_PER_TYPE;
    uint256 public TEAM_RESERVE; // tokens reserved for the team for all sale type
    uint256 public CURRENT_SALE_PIRATE_TYPE;
    uint256 public MAX_PRESALE;
    uint256 public PRE_SALE_MAX;
    uint256 public PUBLIC_SALE_MAX;
    uint256 public CURRENT_TOKEN_ID;

    struct ArrLander {
        uint256 generation;
        uint256 breed_count;
        uint256 bornAt;
        uint256 pirate_type;
    }

    struct PirateType {
        uint256 team_reserve;
        uint256 max_supply;
        bool exists;
        uint256 supply;
    }

    mapping(uint256 => ArrLander) public arrLanders;
    mapping(uint256 => PirateType) public pirate_types;
    mapping(address => bool) public whitelist;
    mapping(address => bool) private spawnPirateAllowedCallers;
    mapping(uint256 => mapping(uint256 => string)) private BASE_URLS; // base urls per generation and type

    bool public hasSaleStarted;
	bool public hasPresaleStarted;

	uint256 public preSalePrice;
    uint256 public publicSalePrice;

    event Sold(address to, uint256 tokenCount, uint256 amount, uint256 timestamp);
    
    function initialize(string memory baseURI, uint256 _team_tokens, uint256 _max_per_type) initializer public {
        __ERC721_init("ArrLandNFT","ARRLDNFT");     
        __Ownable_init();

        TEAM_RESERVE = _team_tokens;
        MAX_PER_TYPE = _max_per_type.sub(TEAM_RESERVE);
        preSalePrice = 40000000000000000; // 0.04 ETH
        publicSalePrice = 70000000000000000; // 0.07 ETH
        MAX_PRESALE = 500;
        PRE_SALE_MAX = 5;
        PUBLIC_SALE_MAX = 10;
        CURRENT_TOKEN_ID = 0;
        CURRENT_SALE_PIRATE_TYPE = 1; // 1 men, 2 women, used for main sale of genesis collection
        pirate_types[CURRENT_SALE_PIRATE_TYPE] = PirateType(TEAM_RESERVE, MAX_PER_TYPE, true, 0);
        BASE_URLS[0][1] = baseURI;
    }

    function mint(uint256 numArrlanders) public payable{
        require(hasSaleStarted || hasPresaleStarted, "Sale has not started");
        require(CURRENT_SALE_PIRATE_TYPE == 1 || CURRENT_SALE_PIRATE_TYPE == 2, "Works on type 1 and 2");
        uint256 max_mint;
        uint256 price;
        if (hasPresaleStarted == true){
            require(whitelist[msg.sender], "The sender isn't eligible for presale");            
            max_mint = PRE_SALE_MAX;
            price = preSalePrice;
        } else {
            max_mint = PUBLIC_SALE_MAX;
            price = publicSalePrice;
        }
        PirateType storage pirate_type = pirate_types[CURRENT_SALE_PIRATE_TYPE]; 
        require(
           pirate_type.supply < MAX_PER_TYPE,
           "Sale has already ended"
        );
        require(numArrlanders > 0 && numArrlanders <= max_mint, "You can mint from 1 to {max_mint} ArrLanders");
        require(
            pirate_type.supply.add(numArrlanders) <= MAX_PER_TYPE,
            "Exceeds MAX_PER_TYPE"
        );
        require(price.mul(numArrlanders) == msg.value, "Not enough Ether sent for this tx");
        if (hasPresaleStarted){
            delete whitelist[msg.sender];
        }
        for (uint i = 0; i < numArrlanders; i++) {
            _spawn_pirate(msg.sender, 0, CURRENT_SALE_PIRATE_TYPE);
        }
        emit Sold(msg.sender, numArrlanders, msg.value, block.timestamp);
    }

    function setPirateSaleType(uint256 pirate_sale_type) public onlyOwner {
        require(pirate_sale_type > 0, "Pirate sale type must be greater then 0");
        CURRENT_SALE_PIRATE_TYPE = pirate_sale_type;
        if (pirate_types[CURRENT_SALE_PIRATE_TYPE].exists == false) {
            pirate_types[CURRENT_SALE_PIRATE_TYPE] = PirateType(TEAM_RESERVE, MAX_PER_TYPE, true, 0);
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory baseURI = BASE_URLS[arrLanders[tokenId].generation][arrLanders[tokenId].pirate_type];
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    function setBaseURI(string memory _baseURI, uint256 generation, uint256 pirate_type_id) public onlyOwner {
        BASE_URLS[generation][pirate_type_id] = _baseURI;    
    }

    function setPUBLIC_SALE_MAX(uint256 _PUBLIC_SALE_MAX) public onlyOwner {
        PUBLIC_SALE_MAX = _PUBLIC_SALE_MAX;
    }

    function setSpawnPirateAllowedCallers(address _externalCaller) public onlyOwner {
        require(_externalCaller != address(0), "Wrong address");
        spawnPirateAllowedCallers[_externalCaller] = true;
    }

    function flipSaleStarted() public onlyOwner {
        hasSaleStarted = !hasSaleStarted;
    }

    function flipPreSaleStarted() public onlyOwner {
        hasPresaleStarted = !hasPresaleStarted;
    }

    function addWalletsToWhiteList(address[] memory _wallets) public onlyOwner{
        for(uint i = 0; i < _wallets.length; i++) {
            whitelist[_wallets[i]] = true;
        }
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    function reserveTokens(uint256 tokenCount) external {
        require(spawnPirateAllowedCallers[msg.sender] == true, "wrong external call");
        _reserveTokens(tokenCount);
    }

    function sendGiveAway(address _to, uint256 _tokenCount, uint256 _generation) external
    {
        require(spawnPirateAllowedCallers[msg.sender] == true, "wrong external call");
        require(CURRENT_SALE_PIRATE_TYPE == 1 || CURRENT_SALE_PIRATE_TYPE == 2, "Giveway works on type 1 and 2");
        _reserveTokens(_tokenCount);
        for (uint i = 0; i < _tokenCount; i++) {
            _spawn_pirate(_to, _generation, CURRENT_SALE_PIRATE_TYPE);            
        }
    }

    function _reserveTokens(uint256 _tokenCount) private {
        PirateType storage pirate_type = pirate_types[CURRENT_SALE_PIRATE_TYPE];
        require(_tokenCount > 0 && _tokenCount <= pirate_type.team_reserve, "Not reserve left");
        pirate_type.team_reserve = pirate_type.team_reserve.sub(_tokenCount);
    }

    function spawn_pirate(
        address _to, uint256 generation, uint256 pirate_type
    )
        external
        returns (uint256)
    {
        require(spawnPirateAllowedCallers[msg.sender] == true, "wrong external call");
        return _spawn_pirate(_to, generation, pirate_type);
    }

    function _spawn_pirate(address to, uint256 generation, uint256 _pirate_type) private returns (uint256) {
        CURRENT_TOKEN_ID = CURRENT_TOKEN_ID.add(1);
        PirateType storage pirate_type = pirate_types[_pirate_type];
        pirate_type.supply = pirate_type.supply.add(1);
        _safeMint(to, CURRENT_TOKEN_ID);
        arrLanders[CURRENT_TOKEN_ID] = ArrLander(generation, 0, block.timestamp, _pirate_type);
        return CURRENT_TOKEN_ID;
    }
}