// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC721.sol";
import "Ownable.sol";
import "ERC721Enumerable.sol";

contract MindBlown is ERC721, ERC721Enumerable, Ownable {
    string private _baseURIextended;
    string public provenanceHash;
    bool public mbSaleActive = false;
    bool public allowListActive = false;    

    uint256 public constant maxTokens = 10000;
    uint8 public constant maxPublicQty = 5;
    uint256 public constant pricePerToken = 0.1 ether;    

    mapping(address => uint8) private _allowListQty;
    mapping(address => uint256) private _allowListPrice;

    constructor() ERC721("Mind-Blown", "M | B") {
    }

    function flipSaleState(uint8[] calldata saleIdArr) external onlyOwner {
        for (uint256 i = 0; i < saleIdArr.length; i++) {
            if (saleIdArr[i] == 1) {                
                allowListActive = !allowListActive;
            } else if (saleIdArr[i] == 2) {
                mbSaleActive = !mbSaleActive;
            }
        }
    }

    function setAllowList(address[] calldata addresses, uint8 numAllowedToMint, uint256 allowListPrice) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _allowListQty[addresses[i]] = numAllowedToMint;
            _allowListPrice[addresses[i]] = allowListPrice;
        }
    }

    function whitelistMintCheck(address addr) external view returns (uint8, uint256) {
        return (_allowListQty[addr], _allowListPrice[addr]);
    }

    function mintAllowList(uint8 numberOfTokens) external payable {
        uint256 ts = totalSupply();
        require(allowListActive, "Allow list is not active");
        require(numberOfTokens <= _allowListQty[msg.sender], "Exceeded max available to purchase");
        require(ts + numberOfTokens <= maxTokens, "Purchase would exceed max tokens");
        require(_allowListPrice[msg.sender] * numberOfTokens <= msg.value, "Ether value sent is not correct");

        _allowListQty[msg.sender] -= numberOfTokens;
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }    

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    function setProvenanceHash(string memory provenance) public onlyOwner {
        provenanceHash = provenance;
    }

    function reserve(uint256 tokenCount) public onlyOwner {
      uint supply = totalSupply();
      uint i;
      for (i = 0; i < tokenCount; i++) {
          _safeMint(msg.sender, supply + i);
      }
    }

    function mint(uint numberOfTokens) public payable {
        uint256 ts = totalSupply();
        require(mbSaleActive, "Sale must be active to mint tokens");
        require(numberOfTokens <= maxPublicQty, "Exceeded max token purchase");
        require(ts + numberOfTokens <= maxTokens, "Purchase would exceed max tokens");
        require(pricePerToken * numberOfTokens <= msg.value, "Ether value sent is not correct");

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }

    function withdraw() public onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}