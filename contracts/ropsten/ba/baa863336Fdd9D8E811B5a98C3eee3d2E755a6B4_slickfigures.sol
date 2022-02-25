// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";


contract slickfigures is ERC721, ERC721Enumerable, Ownable {
    bool public saleIsActive = false;
    string private _baseURIextended;
    address payable public immutable shareholderAddress;

    constructor(address payable shareholderAddress_, string memory _baseURIextended) ERC721("Slick Figures", "SLICK") {
        require(shareholderAddress_ != address(0));
        shareholderAddress = shareholderAddress_;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // function used to set baseURI for metadata directory
    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }

    // returns baseURI for project set by function above
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    // reserves first 150 (or however many) for free minting for our team
    function reserve() public onlyOwner {
        uint supply = totalSupply();
        uint i;
        for (i = 0; i < 150; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    // activates sale
    function setSaleState(bool newState) public onlyOwner {
        saleIsActive = newState;
    }

    // basic public minting function
    function mint(uint numberOfTokens) public payable {
        require(saleIsActive, "Sale must be active to mint Tokens");
        require(numberOfTokens <= 5, "Exceeded max token purchase");
        require(totalSupply() + numberOfTokens <= 100, "Purchase would exceed max supply of tokens");
        require(0.05 ether * numberOfTokens == msg.value, "Ether value sent is not correct");

        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            if (totalSupply() < 100) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    // withdraw function
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(shareholderAddress, balance);
    }
}