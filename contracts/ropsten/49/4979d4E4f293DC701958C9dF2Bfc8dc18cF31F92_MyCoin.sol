//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.1;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract MyCoin is ERC721Upgradeable {
    IERC1155Upgradeable private _currency;
    address private _owner;
    function init(address currency_) public initializer(){
        _currency = IERC1155Upgradeable(currency_);
        _owner = msg.sender;
    }
    
event tokenCreated(uint256 _tokenName);

    function buy( uint256 _QtyFRC, uint256 _QtyTRC) public returns(uint256){
        address _buyer = msg.sender;
        
        _currency.safeTransferFrom(_buyer, _owner, 5, _QtyFRC, "");
        _currency.safeTransferFrom(_buyer, _owner, 10, _QtyTRC, "");
        
        uint256 _tokenName = 10; 
        uint256 _temp = _QtyTRC;
        
        while( _temp > 0) {
            _temp /= 10;
            _tokenName *= 10;
        }
        
        _tokenName = _tokenName * _QtyFRC * 10 + _QtyTRC * 10 + 1;
        console.log(_tokenName);
        _safeMint(_buyer, _tokenName);
        emit tokenCreated(_tokenName);
        return _tokenName;
        
    }
}