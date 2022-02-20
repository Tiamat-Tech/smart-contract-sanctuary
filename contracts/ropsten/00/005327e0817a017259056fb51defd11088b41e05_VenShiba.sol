// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract VenShiba is ERC721, Ownable, Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    uint8 MAX_SUPPLY = 20;
    uint8 MAX_PER_WALLET = 1;
    uint256 PRICE = 0.01 ether;

    constructor() ERC721("VenShiba", "VNS") {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://nft.ven.earth/api/venShiba/metadata/";
    }

    /**
     * @dev Returns an URI for a given token ID
     */
    function tokenURI(uint256 _tokenId)
        public
        pure
        override
        returns (string memory)
    {
        return string(abi.encodePacked(_baseURI(), Strings.toString(_tokenId)));
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function withdraw(address _address) public payable onlyOwner {
        payable(_address).transfer(address(this).balance);
    }

    function mint() public payable {
        require(balanceOf(msg.sender) != MAX_PER_WALLET, "Max amount minted");
        require(msg.value == PRICE, "Price incorrect");

        uint256 tokenId = _tokenIdCounter.current();
        _mint(address(msg.sender), tokenId);
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}