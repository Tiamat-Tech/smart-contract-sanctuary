pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Butter is ERC721, Ownable {

    using Address for address payable;

    // current nft index
    // [] set on deploy
    // [] +1 on successful buy
    uint256 public nftIndex;

    // maximum number of nfts
    // [X] set on deploy
    // [] updatable function only by deployer
    uint256 public maxNftCount;


    // price in ethereum of NFT
    // [] set on deploy
    // [] updatable function only by deployer
    uint256 public currentPrice;

    // artist address
    // [] set on deploy
    // []? updatable by deployer
    address payable artistAddress;


    constructor(uint256 _maxNftCount, uint256 _currentPrice, string memory nftName, string memory nftSymbol) ERC721(nftName, nftSymbol) {
        require(_currentPrice > 0);
        nftIndex = 0;
        maxNftCount = _maxNftCount;
        currentPrice = _currentPrice;
    }

    function setCurrentPrice(uint256 _currentPrice) public onlyOwner {
        require(_currentPrice > 0);
        currentPrice = _currentPrice;
    }

    function buy() payable public {
        require(msg.value >= currentPrice);
        // transfer next available nft 
        
    }

    function huslMint(address to, uint256 id) public virtual {
        _safeMint(to, id);
    }

    function setMaxNFTCount(uint256 _count) public onlyOwner {
        require(_count > maxNftCount);
        maxNftCount = _count;
    }

}