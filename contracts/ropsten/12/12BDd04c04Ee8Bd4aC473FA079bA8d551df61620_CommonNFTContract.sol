// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.0;

contract CommonNFTContract is ERC721Enumerable, Ownable {
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 private _price = 0;

    string private _baseTokenURI;

    constructor(string memory baseURI) ERC721("CommonNFT", "COMMON") {
        setBaseURI(baseURI);
    }


    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }


    // Count is how many they want to mint
    function mint(uint256 _count) public payable {
        // Here is the issue:
        uint256 totalSupply = totalSupply();
        require(
            totalSupply + _count <= MAX_SUPPLY,
            "A transaction of this size would surpass the token limit."
        );
        require(
            totalSupply < MAX_SUPPLY,
            "All tokens have already been minted."
        );
        require(_count < 21, "Exceeds the max token per transaction limit.");
        require(
            msg.value >= _price * _count,
            "The value submitted with this transaction is too low."
        );

        for (uint256 i; i < _count; i++) {
            _safeMint(msg.sender, totalSupply + i);
        }
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        }

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function withdrawAll() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }
}