// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import ".././Ownables/AtWillWithdrawal.sol";
import "./TokenURIERC721Storage.sol";
import "./TokenURIERC721StorageWithAccessControl.sol";

import ".././Royalties/RoyaltiesAsOwner.sol";
import ".././Royalties/RoyaltiesAsCustomAddress.sol";

import "./Mintables/MintableERC721.sol";
import "./Mintables/MintableByOwnerERC721.sol";
import "./Mintables/MintableByAccessControlERC721.sol";
import "./Mintables/MintableERC721WithPrice.sol";
import "./Mintables/AutomaticWithdrawalMintableERC721.sol";

contract VeracuzNFTCollectionScriptLightImplementation is 

    //begin presumed Bill Murray Implementation:

    //ERC721URIStorage
    //TokenURIERC721Storage
    //RoyaltiesAsCustomAddress: for percentage of buy price on third party marketplaces to go to external wallet  
    //MintableERC721URIStorage: for general external minting solution

    //OR

    //TokenURIERC721Storage:
    //RoyaltiesAsCustomAddress: for percentage of buy price on third party marketplaces to go to external wallet set on smart contract deployment
    //MintableByAccessControlERC721: for external wallet set as minter role on smart contract deployment

    //end presumed Bill Murray Implementation

    TokenURIERC721StorageWithAccessControl,
    RoyaltiesAsCustomAddress,
    MintableByAccessControlERC721 {

    constructor(address royaltiesAddress, address minterRoleAddress, address tokenSetter)
    ERC721("OwnableAbsentTest","OT")
    RoyaltiesAsCustomAddress(700, royaltiesAddress)
    MintableByAccessControlERC721(minterRoleAddress)
    TokenURIERC721StorageWithAccessControl(tokenSetter) { }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(MintableByAccessControlERC721, RoyaltiesBase, TokenURIERC721StorageWithAccessControl)
    returns (bool)
    {
        return (
            super.supportsInterface(interfaceId)
        );
    }
}