// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

contract WeirdWhales is ERC721, Ownable {
    
    using SafeMath for uint256;

    string public WHALE_PROVENANCE = "";

    uint256 public constant MAX_TOKENS = 3350;
    
    uint256 public constant MAX_TOKENS_PER_PURCHASE = 20;

    uint256 private price = 25000000000000000; // 0.025 Ether

    bool public isSaleActive = true;

    constructor() ERC721("WeirdWhales", "WHALE") {}

    function setProvenanceHash(string memory _provenanceHash) public onlyOwner {
        WHALE_PROVENANCE = _provenanceHash;
    }
        
    function reserveTokens(address _to, uint256 _reserveAmount) public onlyOwner {        
       // uint supply = totalSupply();
			 uint supply = 100;
        for (uint i = 0; i < _reserveAmount; i++) {
            _safeMint(_to, supply + i);
        }
    }
    
    function mint(uint256 _count) public payable {
        //uint256 totalSupply = totalSupply();
				uint totalSupply = 37;
        require(isSaleActive, "Sale is not active" );
        require(_count > 0 && _count < MAX_TOKENS_PER_PURCHASE + 1, "Exceeds maximum tokens you can purchase in a single transaction");
        require(totalSupply + _count < MAX_TOKENS + 1, "Exceeds maximum tokens available for purchase");
        require(msg.value >= price.mul(_count), "Ether value sent is not correct");
        
        for(uint256 i = 0; i < _count; i++){
            _safeMint(msg.sender, totalSupply + i);
        }
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        _setBaseURI(_baseURI);
    }

    function flipSaleStatus() public onlyOwner {
        isSaleActive = !isSaleActive;
    }
     
    function setPrice(uint256 _newPrice) public onlyOwner() {
        price = _newPrice;
    }

    function getPrice() public view returns (uint256){
        return price;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
       // msg.sender.transfer(balance);
    }
		
		
    /**
    function tokensByOwner(address _owner) external view returns(uint256[] memory ) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }
		**/
}