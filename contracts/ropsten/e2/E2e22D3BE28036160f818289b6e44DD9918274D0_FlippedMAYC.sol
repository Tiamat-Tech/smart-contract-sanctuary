// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract FlippedMAYC is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    uint256 MAX_SUPPLY = 10000;
    uint256 public constant MAX_MINTS = 5;
    uint256 public constant PRICE = 2 * 10**16;

    string private _baseTokenURI;

    constructor() ERC721("NFT Test", "NFTD") {
    }

    function reserve(uint256 n) public onlyOwner {
        for (uint i = 0; i < n; i++) {
            _mint();
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseTokenURI = baseURI_;
    }

    function mint(uint _count) public payable {
        uint total = _tokenIds.current();
        require(_count > 0 && _count <= MAX_MINTS, "Cannot mint specified number of tokens");
        require(total.add(_count) <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(PRICE.mul(_count) <= msg.value, "Ether value sent is not correct");

        for (uint256 i = 0; i < _count; i++) {
            _mint();
        }
    }

    function _mint() private {
        uint newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);
        _tokenIds.increment();
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}