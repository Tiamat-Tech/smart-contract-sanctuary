//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SimpleNFT is Ownable, ERC721 {
    using Counters for Counters.Counter;

    uint256 public immutable totalSupply;
    uint256 public priceIncrementSize;
    uint256 public price;
    Counters.Counter public nextTokenId;
    string private tokenBaseURI;

    event UpdateBaseURI(string _old, string _new);
    event UpdatePriceIncrementSize(uint256 _old, uint256 _new);

    constructor(
        uint256 _totalSupply,
        string memory _tokenBaseURI,
        uint256 _startPrice,
        uint256 _priceIncrementSize
    ) ERC721("SimpleNFT", "SNFT") {
        totalSupply = _totalSupply;
        tokenBaseURI = _tokenBaseURI;
        price = _startPrice;
        priceIncrementSize = _priceIncrementSize;
    }

    /**
     * @dev mint the next NFT, price increment 1 from the last mint
     */
    function mint(address _to) external payable {
        require(msg.value >= price, "Not enough ETH");
        require(nextTokenId.current() < totalSupply, "Reached max supply");
        _safeMint(_to, nextTokenId.current());
        price += priceIncrementSize;
        nextTokenId.increment();
    }

    function setPriceIncrementSize(uint256 _newPriceIncrementSize) external onlyOwner {
        emit UpdatePriceIncrementSize(priceIncrementSize, _newPriceIncrementSize);
        priceIncrementSize = _newPriceIncrementSize;
    }

    function setBaseURI(string calldata _newURI) external onlyOwner {
        emit UpdateBaseURI(tokenBaseURI, _newURI);
        tokenBaseURI = _newURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return tokenBaseURI;
    }
}