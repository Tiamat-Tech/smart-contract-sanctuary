/**
 *Submitted for verification at Etherscan.io on 2021-12-02
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bridge {
    
    uint64 internal _epoch;
    
    mapping(uint8/*networkid*/ => uint64[]) _scanRange;
    
    /* tokens */
    uint8[] allNetworkIds;
   
    mapping(uint8 => address[]) allCrossTokens;
    mapping(uint8 => address[]) allTokens;
    mapping(uint8 => uint256[]) allMinAmounts;
    mapping(uint8 => uint256[]) allTokenTypes;
    mapping(uint8 => uint64[])  allFutureBlocks;
    
    function epoch() public view returns (uint64) {
        return _epoch;
    }

    function scanRange(uint8 networkId) public view returns (uint64[] memory) {
        return _scanRange[networkId];
    }
    
    function processPack(/*pack header*/uint8 networkId,uint64[2] memory blockScanRange,  /*pack body*/uint256[] memory txHashes, address[] memory tokens, address[] memory recipients, uint256[] memory amounts, uint8[] memory v, bytes32[] memory r, bytes32[] memory s) public /*view returns(bytes32)*/ {
        //follow eip191 standard https://eips.ethereum.org/EIPS/eip-191
        bytes32 msgHash = keccak256(abi.encodePacked(bytes1(0x19), bytes1(0), address(this),_epoch,encodeScanRangeArray(blockScanRange), networkId, encodeUint256Array(txHashes), encodeAddressArray(tokens), encodeAddressArray(recipients),encodeUint256Array(amounts)));
        
        require(msgHash!="");
         /*ecrecover for further check*/
         
        //for each $key as $signers {
            //address recovered = ecrecover(msgHash, v[key], r[key], s[key]);
        //}
        
        /*update scanRange*/
        //if ok {
            //scanRange[networkId] = new scan range;
        //}
        
        //return msgHash;/*ignore, chiew test usage*/
    }
      
    function tokens(uint64 searchBlock) public view returns(uint8[] memory, address[][] memory, address[][] memory, uint256[][] memory, uint8[][] memory) {
        
        uint8[] memory retNetworkIds;
        uint retNetworkIdsCount = 0;
        
        address[][] memory retTokens;
        address[][] memory retCrossTokens;
        uint256[][] memory retMinAmounts;
        uint8[][] memory retTokenTypes;
        
        retNetworkIds = new uint8[](allNetworkIds.length);
        retTokens = new address[][](allNetworkIds.length);
        retCrossTokens = new address[][](allNetworkIds.length);
        retMinAmounts = new uint256[][](allNetworkIds.length);
        retTokenTypes = new uint8[][](allNetworkIds.length);
        
        for (uint i=0;i< allNetworkIds.length;i++) {
            
            uint8 networkId = allNetworkIds[i];
            uint retItems = 0;
            for (uint j=allCrossTokens[networkId].length; j>0; j--) {
                if (allFutureBlocks[networkId][ j-1 ] <= searchBlock) {
                   retItems++;
                    bool hasNetwork = false;
                    for(uint k=0;k<retNetworkIds.length;k++) {
                        if (networkId == retNetworkIds[k]) {
                            hasNetwork = true;
                        }
                    }
                    
                    if (!hasNetwork) {
                        retNetworkIds[retNetworkIdsCount] = networkId;
                        retNetworkIdsCount++;
                    }
                }
            }
 
            retTokens[i] = new address[](retItems);
            retCrossTokens[i] = new address[](retItems);
            retMinAmounts[i] = new uint256[](retItems);
            retTokenTypes[i] = new uint8[](retItems);
            
            for (uint j=allCrossTokens[networkId].length; j>0; j--) {
                if (allFutureBlocks[networkId][ j-1 ] <= searchBlock) {
                    retTokens[i][ j-1 ] = allTokens[networkId][j-1];
                    retCrossTokens[i][j-1] = allCrossTokens[networkId][j-1];
                    retMinAmounts[i][j-1] = allMinAmounts[networkId][j-1];
                    retTokenTypes[i] = new uint8[](retItems);
                }
            }
           
        }
      
       return (retNetworkIds,retTokens,retCrossTokens,retMinAmounts, retTokenTypes);
    }
    
      
    function encodeScanRangeArray(uint64[2] memory items) internal pure returns(bytes memory data) {
        for(uint i=0; i<items.length; i++){
            data = abi.encodePacked(data, items[i]);
        }
    }
  
   function encodeAddressArray(address[] memory addresses) internal pure returns(bytes memory data){
        for(uint i=0; i<addresses.length; i++){
            data = abi.encodePacked(data, addresses[i]);
        }
    }
    
    function encodeSignersArray(address[21] memory addresses) internal pure returns(bytes memory data){
        for(uint i=0; i<addresses.length; i++){
            data = abi.encodePacked(data, addresses[i]);
        }
    }
    
    function encodeUint256Array(uint256[] memory items) internal pure returns(bytes memory data) {
        for(uint i=0; i<items.length; i++){
            data = abi.encodePacked(data, items[i]);
        }
    }
    
    function processSigners(uint64 epochBlock, address[] memory signers, uint8[] memory v, bytes32[] memory r, bytes32[] memory s) public /* returns(bytes32)*/ {
        //follow eip191 standard https://eips.ethereum.org/EIPS/eip-191
        bytes32 msgHash = keccak256(abi.encodePacked(bytes1(0x19), bytes1(0), address(0),epochBlock,encodeAddressArray(signers)));
        require(msgHash!="");
      
        /*ecrecover for further check*/
        
        //for each $key as $signers {
            //address recovered = ecrecover(msgHash, v, r, s);
        //}
        
        //if ok {
            _epoch = epochBlock;
        //}
        
       // return msgHash;/*ignore, chiew test usage*/
        
    }
    
   
    /* chiew test, change state variables */
    function resetEpoch() public {
        _epoch = 0;
    }

    function resetScanRange(uint8 networkId, uint64[] memory sr) public {
        _scanRange[networkId] = sr;
    }
    
    function addTokens(uint8 _networkId, address _token,address _crossToken,uint256 _minAmount, uint64 _futureBlock, uint8 _tokenType) public {
        bool hasNetwork = false;
        for(uint i=0;i<allNetworkIds.length;i++) {
            if (_networkId == allNetworkIds[i]) {
                hasNetwork = true;
            }
        }
        
        if (!hasNetwork) {
            allNetworkIds.push(_networkId);
        }
        
        allTokens[_networkId].push(_token);
        allCrossTokens[_networkId].push(_crossToken);
        allMinAmounts[_networkId].push(_minAmount);
        allFutureBlocks[_networkId].push(_futureBlock);
        allTokenTypes[_networkId].push(_tokenType);
    }
    
    function emptyTokens() public {
        // delete allTokens;
        // delete allNetworkIds;
        // delete allCrossTokens;
        // delete allMinAmounts;
        // delete allTokenTypes;
    }
}