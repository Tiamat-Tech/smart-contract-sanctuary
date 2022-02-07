// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import ".././Ownables/AtWillWithdrawal.sol";
import "./TokenURIERC721Storage.sol";

import ".././Royalties/RoyaltiesAsOwner.sol";
import ".././Royalties/RoyaltiesAsCustomAddress.sol";

import "./Mintables/MintableERC721URIStorage.sol";
import "./Mintables/MintableERC721URIStorageWithPrice.sol";
//import "./Mintables/AutomaticWithdrawalMintableERC721URIStorage.sol";
import "./Mintables/AutomaticWithdrawalMintableERC721.sol";

contract VeracruzNFTCollection is 

    //begin presumed Bill Murray Implementation:

    //ERC721URIStorage
    //TokenURIERC721Storage
    //RoyaltiesAsCustomAddress: for percentage of buy price on third party marketplaces to go to external wallet  
    //MintableERC721URIStorage: for general external minting solution

    //end presumed Bill Murray Implementation

    ERC721, AutomaticWithdrawalMintableERC721, 
    AtWillWithdrawal, TokenURIERC721Storage,
    RoyaltiesAsOwner {

    constructor(address addr)
    AutomaticWithdrawalMintableERC721(10000000000000000, addr)
    ERC721("VeracuzNFTCollection","VeraNFT")
    RoyaltiesAsOwner(500) { }

    function _burn(uint256 tokenId) internal override (ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view virtual override (ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721, RoyaltiesBase)
    returns (bool)
    {
        return (
            super.supportsInterface(interfaceId)
        );
    }
}