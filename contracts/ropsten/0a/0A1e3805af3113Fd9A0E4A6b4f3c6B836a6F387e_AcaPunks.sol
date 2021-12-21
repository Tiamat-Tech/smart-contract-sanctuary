// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AcaPunks is ERC721Enumerable, Ownable{
    //SafeMath is no longer needed after solidity 0.8.0
    using Strings for uint;

    // sale parameters
    uint public constant MINT_PRICE = 0.001 ether;
    uint public constant MAX_PURCHASE = 10;
    uint public MAX_SUPPLY = 10000;

    // contract state
    bool public saleIsActive = false;
    string private _baseURIExtended;
    // data structure for randomness
    // if a rid is used before, orderToIndex[rid] will be pointed to its the index that used it
    // at the end of minting, orderToIndex[n-i] = the token id of i-th mint
    mapping(uint => uint) public orderToIndex;

    constructor(string memory name, string memory symbol, string memory baseURI_) ERC721(name, symbol) {
        // metadata at https://gateway.pinata.cloud/ipfs/QmShQ7ajsFdgQKpV1nmuiTrHEJhfaGQXepYaQ5xbheZrFe/
        _baseURIExtended = baseURI_;
    }

    // sale state management
    modifier saleActive {
        require(saleIsActive == true, "Sale is not active at the moment");
        _;
	}

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
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
        require(totalSupply()+n <= MAX_SUPPLY, "Exceeds maximum supply. Please try to mint less tokens.");
        for (uint i = 0; i < n; i++) {
            _safeMint(msg.sender, _randID());
        }
    }

    function mint(uint n) public payable saleActive {
        require(n > 0, "Number of tokens must be greater than 0");
        require(n <= MAX_PURCHASE,"Can only mint up to 10 per purchase");
        require(totalSupply()+n <= MAX_SUPPLY, "Purchase would exceed max supply");
        require(MINT_PRICE*n >= msg.value, "Sent token value is not sufficient");
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

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        // token+1 since the jsons are 1 indexed
        return string(abi.encodePacked(_baseURI(), (tokenId+1).toString(), '.json'));
    }
    
    // emergency withdraw
    function withdraw() public onlyOwner {
        (bool success,) = owner().call{value: address(this).balance}("");
        require(success);
    }
}