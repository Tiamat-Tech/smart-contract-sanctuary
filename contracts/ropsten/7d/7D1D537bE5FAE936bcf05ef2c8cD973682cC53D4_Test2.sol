//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


contract Test2 {
    string private test  = "test3x";
    //mapping (uint => address) private assets;
    address[10] private assets;
    uint private assetCount = 0;
    //uint private assetMax = 10;

    function getTest() public view returns (string memory) {
        return test;
    }

    function getAsset(uint asset) public view returns (address) {
        return assets[asset];
    }

    function mint() public payable {
        require(msg.value == .01 ether);
        assets[assetCount] = msg.sender;
        assetCount++;
    }

    function getOwner(uint assetIndex) public view returns (address) {
        return assets[assetIndex];
    }

    function getAssetCount() public view returns (uint) {
        return assetCount;
    }

}