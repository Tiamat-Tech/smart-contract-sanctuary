//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MyNF2 is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    Counters.Counter private _tokenIds;

    uint public constant MAX_SUPPLY = 16777216;
    uint public constant PRICE = 0.01 ether;
    uint public constant MAX_PER_MINT = 10000;

    string public baseTokenURI;

    constructor(string memory baseURI) ERC721("MyNF2", "NF2") {
      setBaseURI(baseURI);
    }

    function withdraw() public payable onlyOwner{
      uint balance = address(this).balance;
      require(balance > 0, "Contract has no ether to withdraw.");
      (bool success, ) = (msg.sender).call{value: balance}("");
      require(success, "Transfer did not complete.");
    }

    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
      baseTokenURI = _baseTokenURI;
    }

    function _baseURI() internal view virtual override returns (string memory){
      return baseTokenURI;
    }

    function tokensOfOwner(address _owner) external view returns (uint[] memory){
      uint tokenCount = balanceOf(_owner);
      uint[] memory tokensId = new uint256[](tokenCount);
      for(uint i = 0; i < tokenCount; i++){
        tokensId[i] = tokenOfOwnerByIndex(_owner, i);
      }

      return tokensId;
    }

    function _mintSingleColor() private {
      uint newTokenID = _tokenIds.current();
      _safeMint(msg.sender, newTokenID);
      _tokenIds.increment();
    }

    function mintColors(uint _count) public payable {
      uint totalMinted = _tokenIds.current();
      require(
        totalMinted.add(_count) <= MAX_SUPPLY,
        "There are not enough Tokens left in supply to mint this amount."
      );
      require(
        _count > 0 && _count <= MAX_PER_MINT,
        "The amount of tokens is either 0 or more than the maximum number per mint."
      );
      require(
        msg.value >= PRICE.mul(_count),
        "You have not sent enough ether to mint this many tokens."
      );

      for(uint i = 0; i < _count; i++){
        _mintSingleColor();
      }
    }
}