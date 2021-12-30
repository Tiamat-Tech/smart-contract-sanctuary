// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
/**
  _   _ ____      __     _______ 
 | \ | |  _ \   /\\ \   / / ____|
 |  \| | |_) | /  \\ \_/ / |     
 | . ` |  _ < / /\ \\   /| |     
 | |\  | |_) / ____ \| | | |____ 
 |_| \_|____/_/    \_\_|  \_____|
 */
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract nbayc is ERC721, ERC721Enumerable, Ownable {
    bool public isActive = false;
    string private _baseURIextended;
    address payable public immutable shareholderAddress;

    constructor(address payable shareholderAddress_) ERC721("nbayc", "NBAYC") {
        require(shareholderAddress_ != address(0));
        shareholderAddress = shareholderAddress_;
        _baseURIextended = "ipfs://Qm....../";
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    function setSaleState(bool newState) public onlyOwner {
        isActive = newState;
    }

    function freeMint(uint256 numberOfTokens) public {
        require(isActive, "Sale must be active to mint nbaycs");
        require(numberOfTokens <= 3, "Exceeded max token purchase (max 3)");
        require(
            totalSupply() + numberOfTokens <= 1000,
            "Only the 1000 first mphers were free. Please use mint function now ;)"
        );

        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = totalSupply() + 1;
            if (totalSupply() < 1000) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    function mint(uint256 numberOfTokens) public payable {
        require(isActive, "Sale must be active to mint nbaycs");
        require(numberOfTokens <= 10, "Exceeded max token purchase");
        require(
            totalSupply() + numberOfTokens <= 5000,
            "Purchase would exceed max supply of tokens"
        );
        require(
            0.01 ether * numberOfTokens <= msg.value,
            "Ether value sent is not correct"
        );

        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = totalSupply() + 1;
            if (totalSupply() < 5000) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    // function mint4guests(uint256 numberOfTokens, address guestAddr)
    //     public
    //     onlyOwner
    // {
    //     require(numberOfTokens <= 20, "Exceeded max token purchase");
    //     require(totalSupply() + numberOfTokens <= 5000, "Purchase would exceed max supply of tokens");

    //     for(uint i = 0; i < numberOfTokens; i++) {
    //         uint mintIndex = totalSupply() + 1;
    //         if (totalSupply() < 5000) {
    //             _safeMint(guestAddr, mintIndex);
    //         }
    //     }
    // }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(shareholderAddress, balance);
    }
}