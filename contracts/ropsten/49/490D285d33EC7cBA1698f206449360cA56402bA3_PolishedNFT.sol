// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PolishedNFT is ERC721, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenId;
    uint256 public constant MAX_TOKENS = 10;
    uint256 public constant MAX_TOKENS_PER_PURCHASE = 10;
    string public constant BASE_URI = "ipfs://bafybeievlb2hydkorrpko2dsuwgeonhvbrnnc3a6fkeg2c62phocct2aw4/";
    string public constant PROVENANCE_HASH = "62d7990513e5e5e1c715e49ce3d5d8a1f8eaa62ae2a9992af9257fe64baac820";
    uint256 private _price = 5000000000000000;

    constructor() ERC721("PolishedNFT", "POLISHED") {}

    function mintItems(uint256 amount) public payable {
        require(totalSupply().add(amount) <= MAX_TOKENS);
        require(amount <= MAX_TOKENS_PER_PURCHASE);
        require(_price.mul(amount) <= msg.value);

        for (uint i = 0; i < amount; i++) {
            _mintItem(msg.sender);
        }
    }

    function _mintItem(address to) internal returns (uint256) {
        _tokenId.increment();

        uint256 tokenId = _tokenId.current();
        _safeMint(to, tokenId);

        return tokenId;
    }

    function reserve(uint256 amount) public onlyOwner {
        uint256 total = _tokenId.current();

        require(total + amount <= MAX_TOKENS);

        for (uint256 i = total; i < amount; i++) {
            if (i < MAX_TOKENS) {
                _mintItem(msg.sender);
            }
        }
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function totalSupply() public view returns (uint256) {
        return _tokenId.current();
    }

    function _baseURI() internal pure override returns (string memory) {
        return BASE_URI;
    }
}