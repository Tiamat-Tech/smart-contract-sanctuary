// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// interface ILandOrc {
//     function increaseSupply(uint256 amount) external;
// }

contract LandOrcNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Lorc Contract Address
    address lorcAddress;
    // using AccessControl for Roles.Role;
    // Roles.Role private _admin;
    // Roles.Role private _lawyer;
    // Roles.Role private _propertyOwner;
    // Roles.Role private _investor;

    constructor () ERC721("LandOrcNFT", "LAND") {}

    function setLorcAddress(address _lorcAddress) external onlyOwner {
         lorcAddress = _lorcAddress;
    }

    function mintToken(string memory _metadataURI, address _propOwner) external onlyOwner returns (uint256) {
        _tokenIds.increment();
        uint256 id = _tokenIds.current();
        _safeMint(_propOwner, id);
        _setTokenURI(id, _metadataURI);

        // ILandOrc landOrc = ILandOrc(lorcAddress);

        uint256 _totalSupply = _tokenIds.current();
        uint256 _reward = 0;

        if(_totalSupply <= 1000) {   // if else statement
            _reward = 1000000 * 10 ** uint(18);
        } else if(_totalSupply >= 1000 && _totalSupply <= 10000 ){
            _reward = 100000 * 10 ** uint(18);
        } else if(_totalSupply >= 10000 && _totalSupply <= 100000 ){
            _reward = 10000 * 10 ** uint(18);
        } else if(_totalSupply >= 100000 && _totalSupply <= 1000000 ){
            _reward = 1000 * 10 ** uint(18);
        } else if(_totalSupply >= 1000000 && _totalSupply <= 10000000 ){
            _reward = 100 * 10 ** uint(18);
        } else if(_totalSupply >= 10000000 && _totalSupply <= 100000000 ){
            _reward = 10 * 10 ** uint(18);
        } else if(_totalSupply >= 100000000 && _totalSupply <= 1000000000 ){
            _reward = 1 * 10 ** uint(18);
        }

        // landOrc.increaseSupply(_reward);
        if(_reward > 0){
            airdrop(msg.sender, _reward);
        }
        return id;
    }

    function airdrop(address _propOwner, uint256 _amount) internal{
        IERC20 landOrc = IERC20(lorcAddress);
        require(landOrc.balanceOf(address(this)) >= _amount, "LandOrcNFT: Insufficient LORC tokens");
        landOrc.transfer(_propOwner, _amount);
    }
}