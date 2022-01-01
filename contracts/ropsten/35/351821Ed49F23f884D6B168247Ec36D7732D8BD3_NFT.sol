// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFT is ERC721Enumerable, Ownable, ReentrancyGuard{
    using Strings for uint;
    using ECDSA for bytes32;

    // sale parameters
    uint public constant MINT_PRICE = 0.01 ether;
    uint public constant MAX_PURCHASE = 10;
    uint public MAX_SUPPLY = 10000;

    // contract state
    bool public saleIsActive = false;
    bool public publicSaleActive = false;
    address private _signer;
    string private _baseURIExtended;
    // data structure for randomness
    // if a rid is used before, orderToIndex[rid] will be pointed to its the index that used it
    // at the end of minting, orderToIndex[n-i] = the token id of i-th mint
    mapping(uint => uint) private orderToIndex;

    constructor(string memory name, string memory symbol, string memory baseURI_) ERC721(name, symbol) {
        _baseURIExtended = baseURI_;
        _signer = msg.sender;
    }

    // sale state management
    modifier saleActive {
        require(saleIsActive == true, "Sale is not active");
        _;
	}

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function flipPublicSaleActive() external onlyOwner {
        publicSaleActive = !publicSaleActive;
    }

    // random index
    function _randMod(uint mod) internal view returns(uint) {
        return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty, block.number, msg.sender)))%mod;
    }

    function _randID() internal returns(uint) {
        uint id = MAX_SUPPLY-totalSupply()-1;
        uint rid = _randMod(id+1); // rid is less than or equal to id
        uint tmp = orderToIndex[id] > 0 ? orderToIndex[id]: id;
        orderToIndex[id] = orderToIndex[rid] > 0 ? orderToIndex[rid]: rid; // if rid is used, point to the id that used it
        orderToIndex[rid] = tmp; // remember who used this rid
        return orderToIndex[id];
    }

    // token minting
    function reserveTokens(uint n) public onlyOwner {
        require(totalSupply()+n <= MAX_SUPPLY, "NFT: Exceeds maximum supply");
        for (uint i = 0; i < n; i++) {
            _safeMint(msg.sender, _randID());
        }
    }

    function mint(uint n, bytes calldata signature) public payable nonReentrant saleActive {
        if(!publicSaleActive) {
            address signer = keccak256(abi.encodePacked(msg.sender, name())).toEthSignedMessageHash().recover(signature);
            require(signer == _signer, "NFT: not whitelisted to stage 1 sale");
        }
        require(n > 0, "NFT: #tokens must > 0");
        require(n <= MAX_PURCHASE,"NFT: Exceeds maximum #tokens per mint");
        require(totalSupply()+n <= MAX_SUPPLY, "NFT: Exceeds maximum supply");
        require(MINT_PRICE*n <= msg.value, "NFT: Sent value is not sufficient");
        (bool success,) = owner().call{value: msg.value}("");
        require(success);
        for (uint i = 0; i < n; i++) {
            _safeMint(msg.sender, _randID());
        }
    }

    // metadata
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseURIExtended = baseURI_;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURIExtended;
    }

    function tokenURI(uint tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        // token+1 since the jsons are 1 indexed
        return string(abi.encodePacked(_baseURI(), (tokenId+1).toString(), '.json'));
    }

    function getMintedIndex(uint order) public view returns (uint) {
        return orderToIndex[MAX_SUPPLY-order];
    }
    
    // emergency withdraw
    function withdraw() public onlyOwner {
        (bool success,) = owner().call{value: address(this).balance}("");
        require(success);
    }
}