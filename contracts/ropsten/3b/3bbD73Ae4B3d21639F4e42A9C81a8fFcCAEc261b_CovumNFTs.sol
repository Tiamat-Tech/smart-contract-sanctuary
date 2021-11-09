//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "hardhat/console.sol";
import './Marketplace.sol';
contract CovumNFTs is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(address => uint256[]) public ownedNFTs;
    mapping(address => uint256) public ownedNFTcount;
    address marketplace;

    constructor(address _marketplace) ERC721("MyNFT", "NFT") {
        console.log("yes",_marketplace);
        marketplace = _marketplace;
    }

    function getUserNFT(address useradd) public view returns (uint256[] memory) {
        return ownedNFTs[useradd];
    }

    function mintNFT(address recipient, string memory tokenURI)
        public
        returns (uint256)
    {
        uint256 newItemId = _tokenIds.current();
        _tokenIds.increment();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
        ownedNFTs[recipient].push(newItemId);
        ownedNFTcount[recipient]++;
        setApprovalForAll(marketplace, true);
        return newItemId;
    }

     function mintNFTWithRoyalty(address recipient, string memory tokenURI,uint256 royalty,address royaltyAddress)
        public
        returns (uint256)
    {
        uint256 newItemId = _tokenIds.current();
        _tokenIds.increment();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
        ownedNFTs[recipient].push(newItemId);
        ownedNFTcount[recipient]++;
        setApprovalForAll(marketplace, true);
        Marketplace(marketplace).setRoyalty(newItemId,royalty,royaltyAddress);
        return newItemId;
    }
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._transfer(from,to,tokenId);
        ownedNFTs[to].push(tokenId);
        ownedNFTcount[to]++;
        bool found = false;
        uint[] memory newOwnedNFTs = new uint[](ownedNFTs[from].length-1);
        for( uint i = 0; i<ownedNFTs[from].length;i++){
            if(ownedNFTs[from][i]==tokenId){
                found = true;
                ownedNFTcount[from]--;
            }
            if(!found){
                newOwnedNFTs[i] = ownedNFTs[from][i];
            }
            else{
                if(i<ownedNFTs[from].length-1){
                    newOwnedNFTs[i] = ownedNFTs[from][i+1];
                }
            }
        }
        ownedNFTs[from] = newOwnedNFTs;
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
        ownedNFTcount[to]++;
        bool found = false;
        uint[] memory newOwnedNFTs;
        for( uint i = 0; i<ownedNFTs[from].length-1;i++){
            if(ownedNFTs[from][i]==tokenId){
                found = true;
                ownedNFTcount[from]--;
            }
            if(!found){
                newOwnedNFTs[i] = ownedNFTs[from][i];
            }
            else{
                newOwnedNFTs[i] = ownedNFTs[from][i+1];
            }
        }
         ownedNFTs[from] = newOwnedNFTs;
    }
    function _burn(uint256 tokenId) internal virtual override {
         bool found = false;
         uint[] memory newOwnedNFTs;
        for( uint i = 0; i < ownedNFTs[super.ownerOf(tokenId)].length;i++){
            if(ownedNFTs[super.ownerOf(tokenId)][i]==tokenId){
                found = true;
                ownedNFTcount[super.ownerOf(tokenId)]--;
            }
            if(!found){
                newOwnedNFTs[i] = ownedNFTs[super.ownerOf(tokenId)][i];
            }
            else{
                newOwnedNFTs[i] = ownedNFTs[super.ownerOf(tokenId)][i+1];
            }
        }
        ownedNFTs[super.ownerOf(tokenId)] = newOwnedNFTs;
        super._burn(tokenId);
    }
}