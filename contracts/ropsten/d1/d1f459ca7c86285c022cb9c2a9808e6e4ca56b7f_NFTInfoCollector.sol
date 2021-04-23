/**
 *Submitted for verification at Etherscan.io on 2021-04-23
*/

pragma solidity 0.8.4;

// SPDX-License-Identifier: MIT

abstract contract ERC721Base{
    function  balanceOf(address owner) external virtual view returns(uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) public virtual view returns(uint256);
    function tokenURI(uint256 tokenId) public view virtual returns(string memory);
}

contract NFTInfoCollector {
    
    struct NFTInContract{
        address contractAddr;
        NFTInfo[] tokens;
    }
    
    struct NFTInfo {
        uint256 tokenID;
        string metadata;
    }
    
    function aggregateUsingTokenURI(address owner, address[] memory contracts) public view returns (uint256 blockNumber, NFTInContract[] memory returnData) {
        blockNumber = block.number;
        returnData = new NFTInContract[](contracts.length);
        
        for(uint256 contractIndex = 0; contractIndex < contracts.length; contractIndex++) {
            ERC721Base _contract = ERC721Base(contracts[contractIndex]);
            uint256 balance = _contract.balanceOf(owner);
            if(balance > 0){
                NFTInfo[] memory infos = new NFTInfo[](balance);
                for(uint256 tokenIndex = 0; tokenIndex < balance; tokenIndex++){
                    uint256 tokenID = _contract.tokenOfOwnerByIndex(owner, tokenIndex);
                    string memory tokenInfoURI = _contract.tokenURI(tokenID);
                    infos[tokenIndex] = NFTInfo(tokenID, tokenInfoURI);
                }
                returnData[contractIndex].tokens = infos;
            }
        }
    }
    
    struct NFTInfoCustomCall{
        address contractAddr;
        bytes callData;
    }
    struct NFTInContractRaw{
        address contractAddr;
        NFTInfoRaw[] tokens;
    }
    struct NFTInfoRaw{
        uint256 tokenID;
        bytes metadata;
    }
    
    function aggregateUsingProvidedCall(address owner, NFTInfoCustomCall[] memory contractsAndCalls) public returns (uint256 blockNumber, NFTInContractRaw[] memory returnData) {
        blockNumber = block.number;
        returnData = new NFTInContractRaw[](contractsAndCalls.length);

        for(uint256 contractIndex = 0; contractIndex < contractsAndCalls.length; contractIndex++) {
            address currContractAddr = contractsAndCalls[contractIndex].contractAddr;
            ERC721Base _contract = ERC721Base(currContractAddr);
            uint256 balance = _contract.balanceOf(owner);
            if(balance > 0){
                NFTInfoRaw[] memory infos = new NFTInfoRaw[](balance);
                for(uint256 tokenIndex = 0; tokenIndex < balance; tokenIndex++){
                    uint256 tokenID = _contract.tokenOfOwnerByIndex(owner, tokenIndex);
                    (bool success, bytes memory tokenInfoRaw) = currContractAddr.call(contractsAndCalls[contractIndex].callData);
                    require(success);
                    infos[tokenIndex] = NFTInfoRaw(tokenID, tokenInfoRaw);
                }
                returnData[contractIndex].tokens = infos;
            }
        }
    }
}