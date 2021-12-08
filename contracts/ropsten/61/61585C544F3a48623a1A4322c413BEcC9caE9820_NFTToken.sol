pragma solidity ^0.8.6;

// SPDX-License-Identifier: MIT

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { ERC721 } from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import { AccessControl } from '@openzeppelin/contracts/access/AccessControl.sol';

contract NFTToken is Ownable, ERC721 {

    // An address who has permissions to mint NFT
    address public minter;

    mapping(uint256 => string) public tokenUri;

    // The internal NFT ID tracker
    uint256 private _currentNFTId;

    /**
     * @notice Require that the sender is the minter.
     */
    modifier onlyMinter() {
        require(msg.sender == minter, 'Sender is not the minter');
        _;
    }

    constructor(address _minter) ERC721("NFTToken", "NFT") {
        minter = _minter;
    }

    /**
     * @notice Set the token minter.
     * @dev Only callable by the owner when not locked.
     */
    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    function mint() public onlyMinter returns (uint256) {
        return _mintTo(minter, _currentNFTId++);
    }

    /**
     * @notice Mint a NFT with `NFTId` to the provided `to` address.
     */
    function _mintTo(address to, uint256 NFTId) internal returns (uint256) {
        _mint(to, NFTId);
        return NFTId;
    }

    // Set every token URI by owner 
    function setTokenUri(uint256 _tokenID, string memory _tokenUri) public onlyOwner{
        require(_exists(_tokenID), "ERC721Metadata: URI query for nonexistent token");
        tokenUri[_tokenID] = _tokenUri;
    }

    function tokenURI(uint256 _tokenID) public view override returns(string memory){
        require(_exists(_tokenID), "ERC721Metadata: URI query for nonexistent token");
        return tokenUri[_tokenID];
    }
}