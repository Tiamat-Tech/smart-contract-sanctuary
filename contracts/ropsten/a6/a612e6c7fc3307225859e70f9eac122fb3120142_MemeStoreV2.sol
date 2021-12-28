// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
import "hardhat/console.sol";

contract MemeStoreV2 {
    event Response(bool success, bytes data);
    event Change(string message, uint newwVal);

    uint public storedData;
    uint public storedKey;
    function set(uint x) public {
        console.log("The value is %d", x);
        require(x<10000, "Should be less than 5000");
        storedData = x;
        emit Change("set", x);
    }
    function setStore(uint key) public {
        storedKey = key;
    }

    function storeTransferNFT(address payable _addr, address _from, address _to, uint256 _tokenId) public payable {

        (bool success, bytes memory data) = _addr.call{value: msg.value}(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _from, _to, _tokenId)
        );

        emit Response(success, data);
    }

    function storeTransferNFTWithMeme(address payable _addr, address _from, address _to, uint256 _tokenId, address payable _addr2, uint256 _amount) public payable {

        (bool success, bytes memory data) = _addr.call{value: msg.value}(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _from, _to, _tokenId)
        );
        if (success) {
            (bool success2, bytes memory data2) = _addr2.call{value: msg.value}(
                abi.encodeWithSignature("transferFrom(address,address,uint256)", _to, _from, _amount)
            );
            emit Response(success2, data2);
        }

        emit Response(success, data);
    }
}