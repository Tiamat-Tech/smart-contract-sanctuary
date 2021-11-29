// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.12;

import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";


/**
 * @dev Implementation of the {IMonsterBuds} interface.
 * This Contract states the 
 * 
 */

contract MpiV1 is  ERC721URIStorageUpgradeable, OwnableUpgradeable {
    using StringsUpgradeable for uint256;
    
    // token count
    uint256 public tokenCounter;

    // token URI
    string private _beforeUri;

    string private _afterUri;


    /**
     * @dev Sets the initialization
    
     */
    

    // constructor initialisation section

    function initialize() public initializer {
        __ERC721_init("MPI-NFT", "MPI");
        __Ownable_init(msg.sender);
        tokenCounter = 1;
        _beforeUri = "https://s3.amazonaws.com/assets.monsterbuds.io/Monster-Uri/";
        _afterUri = "-token-uri.json";
    }

    // functions Sections

    function beforeUri() external view returns(string memory){
        return _beforeUri;
    }

    function afterUri() external view returns(string memory){
        return _afterUri;
    }

}