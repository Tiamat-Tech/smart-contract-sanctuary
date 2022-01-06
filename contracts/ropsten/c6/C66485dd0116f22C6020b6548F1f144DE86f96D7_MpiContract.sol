// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.12;

interface IMPIContract {

    /**
     * @dev Emitted when new tokens are minted by IMX.
    */

    event AssetMinted(address to, uint256 id, bytes blueprint);
 
    /**
     * @dev Emitted when Ethers are transfer to Payout Address.
    */

   // event TransferEth(address from, address to, uint256 amount, uint256 tokens);

    event TransferEth(address from, address payoutAddress1, uint256 amount1, address payoutAddress2, uint256 amount2, uint256 tokens , uint256 catId , uint256 totalAmountRecieved);

}