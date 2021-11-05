// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract NFT3 is ERC721, Ownable, ERC721URIStorage {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    
    Counters.Counter private _tokenIds;

    bool isMintingActive = false;

    uint256 private mintFee = 0.2 ether;
    
    constructor() ERC721("NFT3", "NFT3") {}


    function getMintFee() public view returns (uint256) {
        return mintFee;
    }

    function activateMint() public onlyOwner {
        isMintingActive = true;
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }


    function mint(string memory _uri) public payable returns (uint256) {
        require(isMintingActive, "Minting is not active.");
        require(msg.value >= mintFee, "Amount of ether sent not enough");
        uint256 tokenId = _tokenIds.current();
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _uri);
        _tokenIds.increment();
        return tokenId;
    }

    function claim(uint256 _tokenId) external payable {
        require(msg.value == mintFee, "Invalid sent value");
        require(
            msg.sender != address(0) && msg.sender != ownerOf(_tokenId),
            "Non-existent address or already owner"
        );

        address _owner = ownerOf(_tokenId);
        payable(_owner).transfer(msg.value);
        setApprovalForAll(_owner, true);
        _transfer(_owner, msg.sender, _tokenId);
    }
}