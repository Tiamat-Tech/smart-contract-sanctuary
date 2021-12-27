// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.0;

import { GenericNFT } from "./GenericNFT.sol";

interface IGenericNFT {
    function makeUniqueNFT(string memory title, string memory nftDescription, string memory cid) external;
}

contract NFTFactory {
    function createNFTContract(string memory _name, string memory _symbol) public {
        new GenericNFT(_name, _symbol);
    }

    function createNFT(address _genericNFT, string memory title, string memory nftDescription, string memory cid) public {
        IGenericNFT(_genericNFT).makeUniqueNFT(title, nftDescription, cid);
    }

}