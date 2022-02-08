// _______                                                   __            __     __                     __                                         
//       \                                                 /  |          /  |   /  |                   /  |                                        
//$$$$$$$  | ______    ______      __   ______    _______  _$$ |_         $$ |   $$ | ______   _______  $$ |   __  _____  ____    ______   _______  
//$$ |__$$ |/      \  /      \    /  | /      \  /       |/ $$   |        $$ |   $$ |/      \ /       \ $$ |  /  |/     \/    \  /      \ /       \ 
//$$    $$//$$$$$$  |/$$$$$$  |   $$/ /$$$$$$  |/$$$$$$$/ $$$$$$/         $$  \ /$$//$$$$$$  |$$$$$$$  |$$ |_/$$/ $$$$$$ $$$$  | $$$$$$  |$$$$$$$  |
//$$$$$$$/ $$ |  $$/ $$ |  $$ |   /  |$$    $$ |$$ |        $$ | __        $$  /$$/ $$    $$ |$$ |  $$ |$$   $$<  $$ | $$ | $$ | /    $$ |$$ |  $$ |
//$$ |     $$ |      $$ \__$$ |   $$ |$$$$$$$$/ $$ \_____   $$ |/  |        $$ $$/  $$$$$$$$/ $$ |  $$ |$$$$$$  \ $$ | $$ | $$ |/$$$$$$$ |$$ |  $$ |
//$$ |     $$ |      $$    $$/    $$ |$$       |$$       |  $$  $$/          $$$/   $$       |$$ |  $$ |$$ | $$  |$$ | $$ | $$ |$$    $$ |$$ |  $$ |
//$$/      $$/        $$$$$$/__   $$ | $$$$$$$/  $$$$$$$/    $$$$/            $/     $$$$$$$/ $$/   $$/ $$/   $$/ $$/  $$/  $$/  $$$$$$$/ $$/   $$/ 
//                        /  \__$$ |                                                                                                              
//                          $$    $$/                                                                                                               
//                           $$$$$$/    

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./TokenURIERC721StorageOnlyByDesignatedRole.sol";
import ".././Royalties/RoyaltiesToCustomAddress.sol";
import "./Mintables/MintableERC721OnlyByDesignatedRole.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract OfficeNFTCollection is 

    TokenURIERC721StorageOnlyByDesignatedRole,
    RoyaltiesToCustomAddress,
    MintableERC721OnlyByDesignatedRole,
    Ownable, ERC721Enumerable
    {

    //@params
    //  @param 1: Address that will be given the MINTER role.
    //  @param 2: Address that will be given the TOKEN_SETTER role.
    //  @param 3: Address which will be paid royalties on each marketplace transaction.
    constructor(address minterRoleAddress, address tokenSetterAddress, address royaltiesAddress)
    //Calls ERC721's constructor to give the token collection a name and symbol. 
    ERC721("LightFeb8thImplementation","LFeb8")
    //Calls MintableERC721OnlyByDesignatedRole's constructor to assign the MINTER role to the passed in address. 
    MintableERC721OnlyByDesignatedRole(minterRoleAddress)
    //Calls TokenURIERC721StorageOnlyByDesignatedRole's constructor to assign the TOKEN_SETTER to the passed in address. 
    TokenURIERC721StorageOnlyByDesignatedRole(tokenSetterAddress)
    //Call RoyaltiesAsCustomAddress's constructor to assign a percentage of royalties from marketplace transactions to be sent to the passed in address. 
    RoyaltiesToCustomAddress(700, royaltiesAddress) { }
    
    //This Smart Contract ultimately derives through association from ERC721 and ERC721URIStorage. Thus, based on the Solidity Compiler v0.8.1,
    //you need to explicity override each of their _burn functions. Since no extra functionality is being added or modified, we simply call their original implementations 
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    //This Smart Contract ultimately derives through association from ERC721 and ERC721URIStorage. Thus, based on the Solidity Compiler v0.8.1,
    //you need to explicity override each of their tokenURI functions. Since no extra functionality is being added or modified, we simply call their original implementations
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override (ERC721Enumerable, ERC721)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    
    function generateWinner() public view onlyOwner returns(address)
    {
        address[] memory owners;

        for (uint256 i = 1; i <= totalSupply(); i++) {
                owners[i] = ownerOf(i);
            }

        uint index = (uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, owners)))) % owners.length;


        return owners[index];
    }

    //Returns whether or not this smart contract or any of its parent implementations' interfaceIds matches the one passed in as the parameter.
    //This allows marketplaces and Web3 technologies to understand what kind of smart contract that they are handling.
    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(MintableERC721OnlyByDesignatedRole, ERC2981Base, TokenURIERC721StorageOnlyByDesignatedRole, ERC721Enumerable)
    returns (bool)
    {
        return (
            super.supportsInterface(interfaceId)
        );
    }
}