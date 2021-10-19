//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract CovumNFTs is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(address => uint256[]) public ownedNFTs;
    mapping(address => uint256) public ownedNFTsCount;
    address marketplace;
    constructor(address _marketplace) ERC721("MyNFT", "NFT") {
        marketplace = _marketplace;
    }

    
    function getUserNFT(address useradd) public view returns (uint256[] memory) {
        return ownedNFTs[useradd];
    }

    function mintNFT(address recipient, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
        ownedNFTs[recipient].push(newItemId);
        setApprovalForAll(marketplace, true);
        return newItemId;
    }
    
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._transfer(from,to,tokenId);
        ownedNFTs[to].push(tokenId);
        for( uint i = 0; i<ownedNFTs[from].length;i++){
            if(ownedNFTs[from][i]==tokenId){
                delete ownedNFTs[from][i];
                break;
            }
        }
    }
    
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual override {
        super._safeTransfer(
        from,
        to,
        tokenId,
        _data
    );
        ownedNFTs[to].push(tokenId);
        for( uint i = 0; i<ownedNFTs[from].length;i++){
            if(ownedNFTs[from][i]==tokenId){
                delete ownedNFTs[from][i];
                break;
            }
        }
    }
    
    function _burn(uint256 tokenId) internal virtual override {
        for( uint i = 0; i< ownedNFTs[super.ownerOf(tokenId)].length;i++){
            if(ownedNFTs[super.ownerOf(tokenId)][i]==tokenId){
                delete ownedNFTs[super.ownerOf(tokenId)][i];
                break;
            }
        }
        super._burn(tokenId);
    }
    
}