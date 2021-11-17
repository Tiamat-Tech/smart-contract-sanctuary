// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Metaverse is ERC721Enumerable, Ownable {
 
    string public baseURI;
    uint256 public constant MAX_SUPPLY = 10000;
    address public minter;
    
    modifier onlyMinter() {
        require(msg.sender == minter, 'Only minter can call');
        _;
    }

    constructor(string memory _name, string memory _symbol, string memory _basTokenUri) ERC721(_name, _symbol) {
        baseURI = _basTokenUri;
    }

    function setBaseTokenURI(string calldata _uri) external onlyOwner() {
        baseURI = _uri;
    }

    function changeMinter(address _minter) external onlyOwner() {
        minter = _minter;
    }
  
    function mint(address _account) public onlyMinter(){
        require(totalSupply() < MAX_SUPPLY, 'Cant mint more NFTs');
        _mint(_account, totalSupply() + 1);
    }

    function batchMint(address _account, uint256 _totalNFT) external onlyMinter() {
        for (uint256 i = 1; i <= _totalNFT; i++) {
            mint(_account);
        }
    }

    function burn(uint256 _nftId) external{
        require(ownerOf(_nftId) == msg.sender, 'Invalid Owner');
        _burn(_nftId);
    }

    function _baseURI() internal override view returns (string memory) {
        return baseURI;
    }
 
}