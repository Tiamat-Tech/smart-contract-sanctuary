//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OhmOwl is ERC721, Ownable {    
    using SafeMath for uint256;
    using Counters for Counters.Counter; 

    uint256 public OWLPRICE = 11000000000000000;
    uint public constant MAXOWLPURCHASE = 3;

    bool public saleIsActive = false;

    // set to my test net address for now
    address t1 = 0x70BFA29ACA546E6cFDc7a8F7Aebf07d9a545Cf52;

    Counters.Counter private _tokenIds;    
    constructor() public ERC721("Ohm OWls", "OWLS") {}    

    function withdraw() public onlyOwner {
        require(payable(t1).send(address(this).balance));
    }

    function setMoondogsPrice(uint256 NewOwlPrice) public onlyOwner {
        OWLPRICE = NewOwlPrice;
    }

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function tokensOfOwner(address _owner) external view returns(uint256[] memory ) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            // Return an empty array
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

    function mintNFT(uint numberOfTokens) public payable {
        require(saleIsActive, "Sale must be active to mint an Owl");
        require(numberOfTokens > 0 && numberOfTokens <= MAXOWLPURCHASE, "You can only mint 3 tokens at a time");
        require(msg.value >= OWLPRICE.mul(numberOfTokens), "Ether value sent is not correct");
        
        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }

    } 






    // function mintNFT(address recipient, string memory tokenURI)        
    //     public        
    //     returns (uint256)    
    // {        
        
    //     _tokenIds.increment();       

    //     uint256 newItemId = _tokenIds.current();        
    //     _mint(recipient, newItemId);        
    //     _setTokenURI(newItemId, tokenURI);       
    //     return newItemId;    
    // }
}