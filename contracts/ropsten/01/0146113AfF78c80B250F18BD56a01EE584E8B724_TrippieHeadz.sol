// contracts/trippieheadz.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


// ascii art


contract TrippieHeadz is ERC721Enumerable, Ownable, ReentrancyGuard {

    using Strings for uint256; 

    uint256 public constant TOTAL_TRIPPIEHEADZ = 9999; // Total Collection for Trippie Headz 
    uint256 public constant RESERVED_SUPPLY = 99; // Amount of TH reserved for the contract
    uint256 public constant MAX_SUPPLY = TOTAL_TRIPPIEHEADZ - RESERVED_SUPPLY; // Maximum amount of TH
    uint256 public constant PRESALE_SUPPLY = 3333; // Presale supply

    // left after presale and reserved: 6,567

    uint256 public constant MAX_PER_TX = 6; // Max amount of TH per tx (public sale)
    uint256 public constant MAX_PER_WALLET_PUBLIC = 6; // Max amount of TH per wallet during public sale.

    uint256 public constant PRICE = 0.099 ether;

    address private constant _a1 = 0x5011D96179317d19A8DBC4F9046dFb7F5c713812; // hidden address 

    // State variables
    // ------------------------------------------------------------------------
    bool public isPresaleActive = false;
    bool public isPublicSaleActive = false;


    // Presale arrays
    // ------------------------------------------------------------------------
    mapping(address => bool) private _presaleEligible;
    mapping(address => uint256) private _presaleClaimed;
    mapping(address => uint256) private _totalClaimed;


    // URI variables
    // ------------------------------------------------------------------------
    string private _contractURI;
    string private _baseTokenURI;


    // Events
    // ------------------------------------------------------------------------
    event BaseTokenURIChanged(string baseTokenURI);
    event ContractURIChanged(string contractURI);


    // Constructor
    // ------------------------------------------------------------------------
    constructor() ERC721("TrippieHeadz", "TRIPPIE") {}



    // Modifiers
    // ------------------------------------------------------------------------
    modifier onlyPresale() {
        require(isPresaleActive, "PRESALE_NOT_ACTIVE");
        _;
    }

    modifier onlyPublicSale() {
        require(isPublicSaleActive, "PUBLIC_SALE_NOT_ACTIVE");
        _;
    }


    // Anti-bot functions
    // ------------------------------------------------------------------------


    function isContractCall(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }


    // Presale functions
    // ------------------------------------------------------------------------
    function addToPresaleList(address[] calldata addresses) external onlyOwner {
        for(uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "NULL_ADDRESS");
            require(!_presaleEligible[addresses[i]], "DUPLICATE_ENTRY");

            _presaleEligible[addresses[i]] = true;
            _presaleClaimed[addresses[i]] = 0;
        }
    }

    function removeFromPresaleList(address[] calldata addresses) external onlyOwner {
        for(uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "NULL_ADDRESS");
            require(_presaleEligible[addresses[i]], "NOT_IN_PRESALE");

            _presaleEligible[addresses[i]] = false;
        }
    }

    function isEligibleForPresale(address addr) external view returns (bool) {
        require(addr != address(0), "NULL_ADDRESS");
        
        return _presaleEligible[addr];
    }

    function hasClaimedPresale(address addr) external view returns (bool) {
        require(addr != address(0), "NULL_ADDRESS");

        return _presaleClaimed[addr] == 1;
    }

    function togglePresaleStatus() external onlyOwner {
        isPresaleActive = !isPresaleActive;
    }

    function togglePublicSaleStatus() external onlyOwner {
        isPublicSaleActive = !isPublicSaleActive;
    }



    // Mint functions
    // ------------------------------------------------------------------------
    function claimReservedTH(uint256 quantity, address addr) external onlyOwner {
        require(totalSupply() >= MAX_SUPPLY, "MUST_REACH_MAX_SUPPLY");
        require(totalSupply() < MAX_SUPPLY, "SOLD_OUT");
        require(totalSupply() + quantity <= MAX_SUPPLY, "EXCEEDS_TOTAL_SUPPLY");

        _safeMint(addr, totalSupply() + 1);
    }

    function claimPresaleTH() external payable onlyPresale {
        uint256 quantity = 1;

        require(_presaleEligible[msg.sender], "NOT_ELIGIBLE_FOR_PRESALE");
        require(_presaleClaimed[msg.sender] < 1, "ALREADY_CLAIMED");

        require(totalSupply() < PRESALE_SUPPLY, "PRESALE_SOLD_OUT");
        require(totalSupply() + quantity <= PRESALE_SUPPLY, "EXCEEDS_PRESALE_SUPPLY");

        require(PRICE * quantity == msg.value, "INVALID_ETH_AMOUNT");

        for (uint256 i = 0; i < quantity; i++) {
            _presaleClaimed[msg.sender] += 1;
            _safeMint(msg.sender, totalSupply() + 1);
        }
    }

    function mint(uint256 quantity) external payable onlyPublicSale {
        require(tx.origin == msg.sender, "GO_AWAY_BOT_ORIGIN");
        require(!isContractCall(msg.sender), "GO_AWAY_BOT_CONTRACT");

        require(totalSupply() < MAX_SUPPLY, "SOLD_OUT");
        require(quantity > 0, "QUANTITY_CANNOT_BE_ZERO");
        require(quantity <= MAX_PER_TX, "EXCEEDS_MAX_MINT");
        require(totalSupply() + quantity <= MAX_SUPPLY, "EXCEEDS_MAX_SUPPLY");

        require(_totalClaimed[msg.sender] + quantity <= MAX_PER_WALLET_PUBLIC, "EXCEEDS_MAX_ALLOWANCE");
        
        require(PRICE * quantity == msg.value, "INVALID_ETH_AMOUNT");

        for (uint256 i = 0; i < quantity; i++) {
            _totalClaimed[msg.sender] += 1;
            _safeMint(msg.sender, totalSupply() + 1);
        }
        
    }


    // Base URI Functions
    // ------------------------------------------------------------------------
    function setContractURI(string calldata URI) external onlyOwner {
        _contractURI = URI;
        emit ContractURIChanged(URI);
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }
    
    function setBaseTokenURI(string calldata URI) external onlyOwner {
        _baseTokenURI = URI;
        emit BaseTokenURIChanged(URI);
    }

    function baseTokenURI() public view returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), "Cannot query non-existent token");
        
        return string(abi.encodePacked(_baseTokenURI, tokenId.toString()));
    }


    // Withdrawal functions
    // ------------------------------------------------------------------------
    function withdrawAll() external onlyOwner {
        uint _a1amount = address(this).balance * 100/100;
        require(payable(_a1).send(_a1amount), "FAILED_TO_SEND_TO_A1");
    }

    function emergencyWithdraw() external onlyOwner {
        payable(_a1).transfer(address(this).balance);
    }
}