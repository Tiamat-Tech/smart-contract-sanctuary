// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract SampleNFT is ERC721Enumerable, Ownable {
    bool public publicSaleIsActive = false;
    bool public presaleIsActive = false;
    bool public revealed = false;

    string public baseURI = "";
    string public previewURI = "";

    uint256 public constant MAX_SUPPLY = 6000;
    uint256 public constant PRICE_PER_TOKEN = 0.06 ether;

    mapping(address => bool) public allowlist;

    constructor() ERC721("SampleNFT", "SAMPLE") {}

    // Internal

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // Public

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    
        if(!revealed) {
            return previewURI;
        }

        return super.tokenURI(tokenId);
    }

    function mint(uint numToMint) public payable {
        if (!publicSaleIsActive) {
            require(presaleIsActive, "Sale is not active");
            require(allowlist[msg.sender] == true, "Sender address is not on allowlist for presale");
        }
        
        uint256 ts = totalSupply();
        require(ts + numToMint <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(PRICE_PER_TOKEN * numToMint <= msg.value, "Not enough Ether sent for the transaction");

        for (uint256 i = 0; i < numToMint; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }

    // Only owner

    function addToAllowlist(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            allowlist[_addresses[i]] = true;
        }
    }

    function removeFromAllowlist(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            allowlist[_addresses[i]] = false;
        }
    }

    function setPreviewURI(string memory _newPreviewUri) external onlyOwner {
        previewURI = _newPreviewUri;
    }

    function setBaseURI(string memory _newBaseUri) external onlyOwner {
        baseURI = _newBaseUri;
    }

    function setPresaleStatus(bool _isActive) external onlyOwner {
        presaleIsActive = _isActive;
    }

    function setPublicSaleStatus(bool _isActive) external onlyOwner {
        publicSaleIsActive = _isActive;
    }

    function revealTokens() external onlyOwner {
        require(bytes(baseURI).length > 0, "The baseURI must be set before revealing");
        revealed = true;
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}