// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import "./utils/Parsing.sol";



contract ArrLandNFTv2 is ERC721Upgradeable, OwnableUpgradeable {
    using StringsUpgradeable for uint256;
    using SafeMathUpgradeable for uint256;

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
        uint256 preSalePrice;
        uint256 publicSalePrice;
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

    address public imx;
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(string memory baseURI, uint256 _team_tokens, uint256 _max_per_type) initializer public {
        __ERC721_init("ArrLandNFT","ARRLDNFT");     
        __Ownable_init();
        //imx = address(0x5FDCCA53617f4d2b9134B29090C87D01058e27e9);
        
        imx = 0x4527BE8f31E2ebFbEF4fCADDb5a17447B27d2aef;
        
    }

    modifier isAllowedCaller() {
        require(spawnPirateAllowedCallers[_msgSender()] == true, "Wrong external call");
        _;
    }

    function totalSupply() public view returns (uint256){ 
        return CURRENT_TOKEN_ID;
    }
    function setPirateSaleType(uint256 pirate_sale_type, uint256 _teamReserve, uint256 _maxPerType, uint256 _preSalePrice, uint256 _publicSalePrice) public onlyOwner {
        require(pirate_sale_type > 0, "Pirate sale type must be greater then 0");
        CURRENT_SALE_PIRATE_TYPE = pirate_sale_type;
        if (pirate_types[CURRENT_SALE_PIRATE_TYPE].exists == false) {
            pirate_types[pirate_sale_type] = PirateType(_teamReserve, _maxPerType.sub(_teamReserve), true, 0, _preSalePrice, _publicSalePrice);
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

    function setSpawnPirateAllowedCallers(address _externalCaller) public onlyOwner {
        require(_externalCaller != address(0), "Wrong address");
        spawnPirateAllowedCallers[_externalCaller] = true;
    }

    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    function reserveTokens(uint256 tokenCount) external isAllowedCaller {
        _reserveTokens(tokenCount);
    }

    function sendGiveAway(address _to, uint256 _tokenCount, uint256 _generation) external isAllowedCaller
    {
        require(CURRENT_SALE_PIRATE_TYPE == 1 || CURRENT_SALE_PIRATE_TYPE == 2, "Giveway works on type 1 and 2");
        _reserveTokens(_tokenCount);
        for (uint i = 0; i < _tokenCount; i++) {
            CURRENT_TOKEN_ID = CURRENT_TOKEN_ID.add(1);
            _spawn_pirate(_to, CURRENT_TOKEN_ID, _generation, CURRENT_SALE_PIRATE_TYPE, 0);            
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
        external isAllowedCaller
        returns (uint256)
    {
        CURRENT_TOKEN_ID = CURRENT_TOKEN_ID.add(1);
        return _spawn_pirate(_to, CURRENT_TOKEN_ID, generation, pirate_type, 0);
    }

    function _spawn_pirate(address to, uint256 tokenID, uint256 generation, uint256 _pirate_type, uint256 _breed_count) private returns (uint256) {
        PirateType storage pirate_type = pirate_types[_pirate_type];
        pirate_type.supply = pirate_type.supply.add(1);
        if (tokenID > CURRENT_TOKEN_ID){
            CURRENT_TOKEN_ID = tokenID;
        }
        _safeMint(to, tokenID);
        arrLanders[CURRENT_TOKEN_ID] = ArrLander(generation, _breed_count, block.timestamp, _pirate_type);
        return CURRENT_TOKEN_ID;
    }

    // implementation of IMintable's mintFor
    // this method gets called upon successful L2-minted asset withdrawal
    function mintFor(
        // address of the receiving user's wallet (must be IMX registered)
        address user,
        // number of tokens that are getting mint, must be 1 for ERC721
        uint256 quantity,
        // blueprint blob, formatted as {tokenId}:{blueprint}
        // blueprint gets passed on L2 mint-time
        bytes calldata mintingBlob
    ) external {
        // quantity MUST be 1 for ERC721 token type
        require(quantity == 1, "Invalid quantity");
        // whitelisting the IMX Smart Contract address
        // this makes sure that you don't accidentally call the function, which could result in clashing token IDs
        require(msg.sender == imx, "Function can only be called by IMX");
        // parsing of the blueprint as implemented by IMX, splits the {tokenId}:{blueprint} into [id, blueprint]
        (uint256 tokenId, uint256 generation, uint256 pirate_type) = Parsing.split(mintingBlob);
        _spawn_pirate(user, tokenId, generation, pirate_type, 0);
    }

    
}