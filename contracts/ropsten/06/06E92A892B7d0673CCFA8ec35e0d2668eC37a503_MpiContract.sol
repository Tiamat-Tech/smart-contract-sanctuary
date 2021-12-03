// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMPIContract {

    /**
     * @dev Emitted when new tokens are minted by IMX.
    */

    event AssetMinted(address to, uint256 id, bytes blueprint);
 
    /**
     * @dev Emitted when Ethers are transfer to Payout Address.
    */

    event TransferEth(address from, address to, uint256 amount, uint256 tokens);

}