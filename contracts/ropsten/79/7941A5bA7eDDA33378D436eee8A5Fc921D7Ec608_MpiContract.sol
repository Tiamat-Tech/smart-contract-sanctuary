// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMPIContract {

    event AssetMinted(address to, uint256 id, bytes blueprint);
 
    event TransferEth(address from, address to, uint256 amount, uint256 tokens);

    function mintFor(
        address to,
        uint256 quantity,
        bytes calldata mintingBlob
    ) external;
}