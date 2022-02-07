// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import ".././Ownables/AtWillWithdrawal.sol";
import "./TokenURIERC721Storage.sol";

import ".././Royalties/RoyaltiesAsOwner.sol";
import ".././Royalties/RoyaltiesAsCustomAddress.sol";

import "./Mintables/MintableERC721URIStorage.sol";
import "./Mintables/MintableERC721URIStorageWithPrice.sol";
import "./Mintables/AutomaticWithdrawalMintableERC721URIStorage.sol";

contract VeracruzNFTCollection is 

    //begin presumed Bill Murray Implementation:

    //ERC721URIStorage
    //TokenURIERC721Storage
    //RoyaltiesAsCustomAddress: for percentage of buy price on third party marketplaces to go to external wallet  
    //MintableERC721URIStorage: for general external minting solution

    //end presumed Bill Murray Implementation

    ERC721URIStorage, AutomaticWithdrawalMintableERC721URIStorage, 
    AtWillWithdrawal, TokenURIERC721Storage,
    RoyaltiesAsOwner {

    constructor(address addr)
    AutomaticWithdrawalMintableERC721URIStorage(10000000000000000, addr)
    ERC721("VeracuzNFTCollection","VeraNFT")
    RoyaltiesAsOwner(500) { }

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