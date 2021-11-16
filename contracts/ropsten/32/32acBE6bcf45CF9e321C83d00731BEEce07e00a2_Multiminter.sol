//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract DeployedPunknpunks {
    function mintedTokenIds() public view returns (uint256[] memory) {}
    function mintNFT(address recipient, uint256 pnpId) public payable returns (uint256) {}
}


contract Multiminter is Ownable {
    uint256 public constant MAX_SUPPLY = 10000;
    // Needed functions from minting contract.
    DeployedPunknpunks pnp;

    constructor(address _address) {
        // _address of the punknpunk contract on arbitrum.
        pnp = DeployedPunknpunks(_address);
    }

    function setWrapContract(address _address) public onlyOwner {
        pnp = DeployedPunknpunks(_address);
    }

    //TODO!!! Not needed.
    function getMinted() public view returns (uint256[] memory) {
        return(pnp.mintedTokenIds());
    }

    function multiMintNFT(address recipient, uint256[] memory pnpIds) public payable returns(uint256[] memory) {
        for (uint i=0; i < pnpIds.length; i++) {
            pnp.mintNFT(recipient, pnpIds[i]);
        }
        return pnpIds;
    }

}