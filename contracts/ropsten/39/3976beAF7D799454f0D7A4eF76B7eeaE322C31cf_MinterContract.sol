///SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@imtbl/imx-contracts/contracts/Mintable.sol";

interface NFTMint {
    function mintToken(address to) external;
}

contract MinterContract is Mintable {

    address immutableX;
    address contractAddr;
    NFTMint nft;

    constructor(address _immutable, NFTMint _contractAddr ) Mintable(msg.sender,_immutable){
        nft = _contractAddr;
    }

    function _mintFor(
        address to,
        uint256 id,
        bytes memory blueprint
    ) internal override {
        require(msg.sender == immutableX,"only immutable");
        nft.mintToken(to);
    }

}