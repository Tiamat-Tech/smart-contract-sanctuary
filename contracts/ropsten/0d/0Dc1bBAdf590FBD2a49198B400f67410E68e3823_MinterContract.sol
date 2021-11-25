///SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@imtbl/imx-contracts/contracts/Mintable.sol";

interface NFTMint {
    function mintToken(address to) external;
}

contract MinterContract is IMintable{

    address immutableX;
    address contractAddr;
    NFTMint nft;

    constructor(address _immutable, NFTMint _contractAddr ){
        immutableX = _immutable;
        nft = _contractAddr;
    }

    function mintFor(
        address to,
        uint256 quantity,
        bytes calldata mintingBlob
    ) external override {
        require(msg.sender == immutableX,"only immutable");
        nft.mintToken(to);
    }

}