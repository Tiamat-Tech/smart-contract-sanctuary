//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "./ERC721Custom.sol";

contract Test2  {
    address[10] private assets;
    uint private assetCount = 0;

    function mint() public payable {
        require(msg.value == .001 ether);
        assets[assetCount] = msg.sender;
        assetCount++;
    }

    function getOwner(uint assetIndex) public view returns (address) {
        return assets[assetIndex];
    }

    function getAssetCount() public view returns (uint) {
        return assetCount;
    }

    // ERC STUFF
    function name() public pure returns (string memory) {
        return "H3X Test";
    }
    function symbol() public pure returns (string memory) {
        return "TEST3X";
    }
    function totalSupply() public pure returns (uint) {
        return 10;
    }
    function balanceOf(address _owner) public view returns (uint) {
        uint count = 0;
        for (uint i = 0; i < assetCount; i++) {
            if (assets[i] == _owner) {
                return count++;
            }
        }
        return count;
    }
    // Functions that define ownership
    function ownerOf(uint256 _tokenId) public view returns (address) {
        return assets[_tokenId];
    }
    function approve(address _to, uint256 _tokenId) public payable {

    }
    //function takeOwnership(uint256 _tokenId) public payable;
    function transfer(address _to, uint256 _tokenId) public payable {
        assets[_tokenId] = _to;
    }
    //function tokenOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint tokenId);
    // Token metadata
    //function tokenMetadata(uint256 _tokenId) public view returns (string memory);
    // Events
    event Transfer(address indexed _from, address indexed _to, uint256 _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 _tokenId);

}