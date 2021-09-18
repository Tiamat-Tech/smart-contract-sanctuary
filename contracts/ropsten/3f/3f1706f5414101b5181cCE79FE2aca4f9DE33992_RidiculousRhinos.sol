// SPDX-License-Identifier: MIT
// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721

pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";

contract RidiculousRhinos is ERC721, Ownable {
    
    using SafeMath for uint256;

    /**
     * Set provenance hash
     */

    string public Rhino_provenance = "";

    /**
     * Max tokens that are mintable 
     */

    uint256 public constant maxTokenSupply = 10000;

    /**
     * Max tokens allowed per TXN
     */

    uint256 public constant MAX_MINTS_PER_TXN = 16;

    /**
     * Tokens itital price
     */

    uint256 public price = 33300000 gwei; // 0.0333 Ether

    /**
     * Checks if the sale is active
     */

    bool public isSaleActive = false;



    constructor() ERC721("RidiculousRhinos", "RHINO") {}

    function reserveTokens(address _to, uint256 _reserveAmount) public onlyOwner {        
        uint supply = totalSupply();
        for (uint i = 0; i < _reserveAmount; i++) {
            _safeMint(_to, supply + i);
        }
    } 

    /**
     * Mint A New Token.
     */
    
    function mint(uint256 _count) public payable {
        uint256 totalSupply = totalSupply();

        require(isSaleActive, "Sale is not active" );
        require(_count > 0 && _count < MAX_MINTS_PER_TXN + 1, "Exceeds maximum tokens you can purchase in a single transaction");
        require(totalSupply + _count < maxTokenSupply + 1, "Exceeds maximum tokens available for purchase");
        require(msg.value >= price.mul(_count), "Ether value sent is not correct");
        
        for(uint256 i = 0; i < _count; i++){
            _safeMint(msg.sender, totalSupply + i);
        }
    }

    /**
     * Set the baseURI
     */

    function setBaseURI(string memory _baseURI) public onlyOwner {
        _setBaseURI(_baseURI);
    }

    /**
     * Change the sale status 
     */


    function flipSaleStatus() public onlyOwner {
        isSaleActive = !isSaleActive;
    }

    /**
     * Set price for sale
     */

    function setPrice(uint256 _newPrice) public onlyOwner() {
        price = _newPrice;
    }

    /**
     * Allows anyone to view the current sales price
     */

    function getPrice() public view returns (uint256){
        return price;
    }

    /**
     * Set provenance hash when calculated
     */

    function setProvenanceHash(string memory _provenanceHash) public onlyOwner {
        Rhino_provenance = _provenanceHash;
    }

    /**
     * Allows owner to withdraw tokens
     */

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        msg.sender.transfer(balance);
    }

    /**
     * Allows anyone to view tokens owned by the owner
     */

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



}