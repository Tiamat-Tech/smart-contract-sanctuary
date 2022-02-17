// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.5;
pragma experimental ABIEncoderV2;


import "./FixinERC721Spender.sol";
import "./libs/LibNFTOrder.sol";
import "./libs/LibSignature.sol";

/// @dev Wrapper for ERC721OrdersFeature to route purchase to target.
contract ZeroExV4NftWrapper is FixinERC721Spender {

    // Proxy contract https://github.com/0xProject/protocol/blob/refactor/nft-orders/contracts/zero-ex/contracts/src/ZeroEx.sol
    address internal zeroExGateway; 

    // Method selector for buyERC721
    bytes4 internal constant buyERC721Signature = 0xfbee349d; 

    constructor(address _zeroExGateway) public {
	     zeroExGateway = _zeroExGateway;
    }

    receive() external payable {}

    /// @dev Transfers an ERC721 asset from `maker` to `to`.
    /// @param sellOrder The ERC721 sell order.
    /// @param signature The order signature.
    /// @param callbackData If this parameter is non-zero, invokes
    ///        `zeroExERC721OrderCallback` on `msg.sender` after
    ///        the ERC721 asset has been transferred to `msg.sender`
    ///        but before transferring the ERC20 tokens to the seller.
    ///        Native tokens acquired during the callback can be used
    ///        to fill the order.
    /// @param to address to transfer ERC721 asset.
    function buyERC721For(
      LibNFTOrder.ERC721Order calldata sellOrder,
      LibSignature.Signature  calldata signature,
      bytes memory callbackData,
      address to
    ) external payable {

        (bool success, bytes memory returnData) =  payable(zeroExGateway).call{value: msg.value}(abi.encodeWithSelector(buyERC721Signature, sellOrder, signature, callbackData));
        require(success, string(returnData));

       // Transfer ERC721 asset to target
       _transferERC721AssetFrom(sellOrder.erc721Token, address(this), to, sellOrder.erc721TokenId);
       
    }
}