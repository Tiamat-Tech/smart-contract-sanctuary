pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Gooloos is ERC721, Ownable {
    using SafeMath for uint256;
    uint public constant MAX_GOOLOOS = 10000;
    bool public hasSaleStarted = false;

    string public METADATA_PROVENANCE_HASH = "";

    string public constant R = "You can be gooloo and still be cute. Cuteness is Justice.";

    constructor(string memory baseURI) ERC721("Gooloos","GOOLOOS")  {
        setBaseURI(baseURI);
    }
    
    function tokensOfOwner(address _owner) external view returns(uint256[] memory ) {
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
    
    function calculatePrice() public view returns (uint256) {
        require(hasSaleStarted == true, "Sale hasn't started");
        require(totalSupply() < MAX_GOOLOOS, "Sale has already ended");

        uint currentSupply = totalSupply();
        return calculatePriceForToken(currentSupply);
    }

    function calculatePriceForToken(uint _id) public view returns (uint256) {
        require(_id < MAX_GOOLOOS, "Sale has already ended");

        if (_id >= 9900) {
            return 1 * 10 ** 18;                // 9900-10000: 1.00 ETH
        } else if (_id >= 9500) {
            return 0.64 * 10 ** 18;             // 9500-9500:  0.64 ETH
        } else if (_id >= 7500) {
            return 0.32 * 10 ** 18;             // 7500-9500:  0.32 ETH
        } else if (_id >= 3500) {
            return 0.16 * 10 ** 18;             // 3500-7500:  0.16 ETH
        } else if (_id >= 1500) {
            return 0.08 * 10 ** 18;             // 1500-3500:  0.08 ETH 
        } else if (_id >= 500) {
            return 0.04 * 10 ** 18;             // 500-1500:   0.04 ETH 
        } else {
            return 0.02 * 10 ** 18;             // 0 - 500     0.02 ETH
        }
    }
    
   function adoptGooloo(uint256 numGooloos) public payable {
        require(totalSupply() < MAX_GOOLOOS, "Sale has already ended");
        require(numGooloos > 0 && numGooloos <= 20, "You can adopt minimum 1, maximum 20 gooloos");
        require(totalSupply().add(numGooloos) <= MAX_GOOLOOS, "Exceeds MAX_GOOLOOS");
        require(msg.value >= calculatePrice().mul(numGooloos), "Ether value sent is below the price");

        for (uint i = 0; i < numGooloos; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }
    }
    
    function setProvenanceHash(string memory _hash) public onlyOwner {
        METADATA_PROVENANCE_HASH = _hash;
    }
    
    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }
    
    function startSale() public onlyOwner {
        hasSaleStarted = true;
    }
    function pauseSale() public onlyOwner {
        hasSaleStarted = false;
    }
    
    function withdrawAll() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    function reserveGiveaway(uint256 numGooloos) public onlyOwner {
        uint currentSupply = totalSupply();
        require(totalSupply().add(numGooloos) <= 30, "Exceeded giveaway supply");
        require(hasSaleStarted == false, "Sale has already started");
        uint256 index;
        for (index = 0; index < numGooloos; index++) {
            _safeMint(owner(), currentSupply + index);
        }
    }
}