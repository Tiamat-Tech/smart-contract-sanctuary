//SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/// @custom:security-contact [email protected]
contract Mike is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;


    // new tutorial
    // promenne nastalo
    uint public constant MAX_SUPPLY = 7777;
    uint public constant PRICE = 0.01 ether;
    uint public constant MAX_PER_MINT = 7;

    string public baseTokenURI;

    constructor(string memory baseURI) ERC721("Mike", "MFTX") {
        setBaseURI(baseURI);
    }

    // rezervace tokenu adminem
    function reserveNFTs() public onlyOwner {
        uint totalMinted = _tokenIds.current();
        require(
            totalMinted.add(7) < MAX_SUPPLY, "Not enough NFTs"
        );
        for (uint i = 0; i < 7; i++) {
            _mintSingleNFT();
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
     return baseTokenURI;
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    // zpracovani jednoho tokenu
    function mintNFTs(uint _count) public payable {
        uint totalMinted = _tokenIds.current();
        require(
        totalMinted.add(_count) <= MAX_SUPPLY, "Not enough NFTs!"
        );
        require(
        _count > 0 && _count <= MAX_PER_MINT, 
        "Cannot mint specified number of NFTs."
        );
        require(
        msg.value >= PRICE.mul(_count), 
        "Not enough ether to purchase NFTs."
        );
        for (uint i = 0; i < _count; i++) {
                _mintSingleNFT();
        }
    }

    // inner mint - tady je mint spojenej s konkretnim kupujicim uz
    // sender = kupujici
    function _mintSingleNFT() private {
        uint newTokenID = _tokenIds.current();
        _safeMint(msg.sender, newTokenID);
        _tokenIds.increment();
    }

    // vyber penez z kontraktu
    function withdraw() public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");
        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }
    
    // vrat tokeny jednoho uzivatele
	function tokensOfOwner(address _owner) 
         	external 
         	view 
         	returns (uint[] memory) {
     	uint tokenCount = balanceOf(_owner);
     	uint[] memory tokensId = new uint256[](tokenCount);
     	for (uint i = 0; i < tokenCount; i++) {
          	tokensId[i] = tokenOfOwnerByIndex(_owner, i);
     	}
	
     	return tokensId;
	}

}