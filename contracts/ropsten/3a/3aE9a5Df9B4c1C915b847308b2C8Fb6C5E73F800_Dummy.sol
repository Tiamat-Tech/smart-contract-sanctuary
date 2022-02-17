// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Dummy is ERC721A, Ownable {
    using Address for address;

    // variables
    string public baseTokenURI;
    uint256 public mintPrice = 0 ether;

    // constructor
    constructor() ERC721A("Dummy", "D") {}

    // public mint
    function publicMint(uint amount) external payable {
        _mintWithoutValidation(msg.sender, amount);
    }

    function _mintWithoutValidation(address to, uint256 amount) internal {
        _safeMint(to, amount);
    }

    function setBaseTokenURI(string memory _baseTokenURI) external onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function withdrawAll() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = address(this.owner()).call{value: amount}("");
        require(success, "Failed to send ether");
    }

    // view
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A)
        returns (string memory)
    {
        return
            string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId)));
    }
}