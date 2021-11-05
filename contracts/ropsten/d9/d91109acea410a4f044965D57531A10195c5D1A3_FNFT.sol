// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

contract FNFT is ERC721, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string public lowImageURI;
    string public highImageURI;
    uint256 public status;
    event CreatedFeedsNFT(uint256 indexed tokenId);

    constructor(
    ) ERC721("NFT", "NFT")
        public
    {   
        status = 0;
    }

    function addLowSVG(string memory _svgLowURI) public onlyOwner {
        lowImageURI = _svgLowURI;
    }
    function addHighSVG(string memory _svgHighURI) public onlyOwner {
        highImageURI = _svgHighURI;
    }
    function evolve() public onlyOwner {
        if(status == 0){
            status = 1;
        }
        else{
            status = 0;
        }
    }

    function mintNFT(address recipient)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);

        return newItemId;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory imageURI = lowImageURI;
        if(status == 1){
            imageURI = highImageURI;
        }
        return imageURI;
    }
}