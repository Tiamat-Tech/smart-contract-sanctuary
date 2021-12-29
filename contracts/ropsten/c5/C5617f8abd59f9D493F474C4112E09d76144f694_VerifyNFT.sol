//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract VerifyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor(string memory name, string memory symbol) public ERC721(name, symbol) {}

    function mintNFT(address recipient, string memory tokenURI)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }

    function transferFrom(
            address from,
            address to,
            uint256 tokenId
        ) public virtual override {
            //solhint-disable-next-line max-line-length
            require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner or approved");

            _transfer(from, to, tokenId);
        }

    function transfer(address _buyer, uint256 _tokenId) external payable returns(bool){
            // transfer assets from seller to buyer
            // seller pays the tx fees

            require(ownerOf(_tokenId) == msg.sender, "NOT OWNER");
            address ownerAddress = ownerOf(_tokenId);
            approve(_buyer, _tokenId);
            setApprovalForAll(msg.sender, true);
            safeTransferFrom(ownerAddress, _buyer, _tokenId);
            return true;
        }
}