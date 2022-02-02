// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;
import "./IterableMapping.sol";

contract FunTypes {

    modifier _ownerOnly(){
        require(isOwner[msg.sender] == true);
        _;
    }
    struct SaleInfo {
        uint128 _maxPerWallet; // Unsigned integer
        int128 _price; // Signed integer
    }
    SaleInfo saleInfo;
    
    enum Choices { Yes, No, Maybe }
    bool _publicMintStarted = false; // Boolean
    fixed _notSupported;
    string _literal = "\'Literal String\'";
    address _treasuryContract = 0x3aCC167374Fb6FA8cbDd8a9Ec03D20B9cE1E4170; // Address
    address[] whitelisted = [0xd3f6f8c99f7cC38c01B503bbf7dC90F384423530,0x7de7dc1746442a79eF6b18De429E50B3f69FE1E8,0x21E2c2EC375B87699a79598E690D7b8F48386E0a]; // Address array
    mapping(address => bool) isOwner; // Mapping
    bytes32 _bytes; // Fixed-size bytes array
    bytes _dbytes; // Dynamically sized byte array
    itmap _data; // Iterable Mapping
    using IterableMapping for itmap; // Use the library stored in IterableMapping.sol
    
    function setSaleSettings(uint128 _maxPer, int128 _priceInWei) public _ownerOnly() {
        saleInfo = SaleInfo(_maxPer, _priceInWei);
    }
}