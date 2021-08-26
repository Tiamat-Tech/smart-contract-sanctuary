// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;


import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// import "../node_modules/openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "../node_modules/openzeppelin-solidity/contracts/access/Ownable.sol";
// import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

contract ChickenSuspects is ERC721Enumerable, Ownable {
    
    using SafeMath for uint256;


    string public _baseTokenURI;
    uint256 public constant MAX_TOKENS = 4419;
    uint256 public constant MAX_TOKENS_PER_PURCHASE = 20;
    
    uint256 private price = 25000000000000000; // 0.025 Ether

    bool public isSaleActive = true;

    constructor() ERC721("Chicken Suspects", "CS") {
    }
    
    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }
    
    function changeSaleStatus() public onlyOwner {
        isSaleActive = !isSaleActive;
    }
    
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }


    function mint(uint256 _count) public payable {
        uint256 totalSupply = totalSupply();

        require(isSaleActive, "Sale is not active" );
        require(_count > 0 && _count < MAX_TOKENS_PER_PURCHASE + 1, "Exceeds maximum tokens you can purchase in a single transaction");
        require(totalSupply + _count < MAX_TOKENS + 1, "Exceeds maximum tokens available for purchase");
        require(msg.value >= price.mul(_count), "Ether value sent is not correct");
        
        for(uint256 i = 0; i < _count; i++){
            _safeMint(msg.sender, totalSupply + i);
        }
    }

    function tokensOfOwner(address owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokenIds;
    }

    function withdrawAll() public payable onlyOwner {
        require(payable(_msgSender()).send(address(this).balance));
    }
}