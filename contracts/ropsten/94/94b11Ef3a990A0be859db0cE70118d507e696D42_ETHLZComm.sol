pragma solidity ^0.7.6;

import "hardhat/console.sol";
import '../interfaces/ILayerZeroEndpoint.sol';
import '../interfaces/ILayerZeroReceiver.sol';

contract ETHLZComm is ILayerZeroReceiver {
    
    // keep track of how many messages have been received from other chains
    uint messageCounter; 
    // required: the LayerZero endpoint which is passed in the constructor
    ILayerZeroEndpoint public endpoint;
    // required: the LayerZero endpoint
    constructor(address _endpoint)  {
        endpoint = ILayerZeroEndpoint(_endpoint);
    }
    // overrides lzReceive function in ILayerZeroReceiver.
    // automatically invoked on the receiving chain after the source chain calls endpoint.send(...)
    function lzReceive(uint16 , bytes memory _fromAddress, uint64 _nonce, bytes memory _payload) override external {
        require(msg.sender == address(endpoint), 'endpoint not correct');
        messageCounter += 1;
        console.log("countUp: count =", messageCounter);
    }
    // custom function that wraps endpoint.send(...) which will 
    // cause lzReceive() to be called on the destination chain!
    function incrementCounter(uint16 _chainId, bytes calldata _endpoint) public payable {
        endpoint.send{value:msg.value}(_chainId, _endpoint, bytes(""), msg.sender, address(this), bytes(""));
    }

    function getCounter() public view returns(uint) {
        return messageCounter;
    }
    
}