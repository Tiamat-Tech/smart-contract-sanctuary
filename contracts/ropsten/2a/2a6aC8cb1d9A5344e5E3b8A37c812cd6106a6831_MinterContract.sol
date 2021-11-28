///SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@imtbl/imx-contracts/contracts/Mintable.sol";

interface NFTMint {
    function mintToken(address to) external;
}

contract MinterContract {

    address immutableX;
    address contractAddr;
    NFTMint nft;

    constructor(address _immutable, NFTMint _contractAddr ){
        nft = _contractAddr;
        immutableX = _immutable;
    }

    function mintFor(
        address to,
        uint256 id,
        bytes memory blueprint
    ) public {
        require(msg.sender == immutableX,"only immutable");
        nft.mintToken(to);
    }

}