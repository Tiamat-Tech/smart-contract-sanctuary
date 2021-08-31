// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract UnitedMetaverseNation is ERC721("United Metaverse Nation", "UMN"), ERC721Enumerable, Ownable, Pausable {
    using SafeMath for uint256;
    using Strings for uint256;

    /*
     * Currently Assuming there will be one baseURI.
     * If it fails to upload all NFTs data under one baseURI,
     * we will divide baseURI and tokenURI function will be changed accordingly.
    */
    string private baseURI;
    string private blindURI;

    uint256 public BUY_LIMIT_PER_TX = 10;
    uint256 public MAX_NFT = 11111;
    uint256 public NFTPrice = 100000000000000000;  // 0.1 ETH
    bool public reveal = false;

    /*
     * Function to reveal all NFTs
    */
    function revealNow() external onlyOwner {
        reveal = true;
    }

    /*
     * Function to withdraw collected amount during minting
    */
    function withdraw(address _to) public onlyOwner {
        uint balance = address(this).balance;
        payable(_to).transfer(balance);
    }

    /*
     * Function to mint new NFTs
     * It is payable. Amount is calculated as per (NFTPrice*_numOfTokens)
    */
    function mintNFT(uint256 _numOfTokens) public payable whenNotPaused {
        if(!reveal)
            require(_msgSender() == owner(), "You are not admin");
        require(_numOfTokens <= BUY_LIMIT_PER_TX, "Can't mint above limit");
        require(totalSupply().add(_numOfTokens) <= MAX_NFT, "Purchase would exceed max supply of NFTs");
        require(NFTPrice.mul(_numOfTokens) == msg.value, "Ether value sent is not correct");
        
        for(uint i=0; i < _numOfTokens; i++) {
            _safeMint(msg.sender, totalSupply());
        }
    }

    /*
     * Function to get token URI of given token ID
     * URI will be blank untill totalSupply reaches MAX_NFT
    */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        if (!reveal) {
            return string(abi.encodePacked(blindURI, tokenId.toString()));
        } else {
            return string(abi.encodePacked(baseURI, tokenId.toString()));
        }
    }

    /*
     * Function to set Base and Blind URI 
    */
    function setURIs(string memory _blindURI, string memory _URI) external onlyOwner {
        blindURI = _blindURI;
        baseURI = _URI;
    }

    /*
     * Function to pause 
    */
    function pause() external onlyOwner {
        _pause();
    }

    /*
     * Function to unpause 
    */
    function unpause() external onlyOwner {
        _unpause();
    }

    // Standard functions to be overridden 
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, 
    ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}