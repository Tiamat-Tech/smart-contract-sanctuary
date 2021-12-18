// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./LibOrder.sol";
import "./lib/LibAsset.sol";
import "./OrderValidator.sol";
import "./TransferExecutor.sol";
import "./TransferManager.sol";

contract Market721 is Initializable, TransferExecutor, OrderValidator, TransferManager {

    function initialize(uint newProtocolFee, address newDefaultFeeReceiver) external initializer {
        __Context_init();
        __Ownable_init();
        __OrderValidator_init();
        __TransferManager_init(newProtocolFee, newDefaultFeeReceiver);
    }

    function matchOrders(
        LibOrder.Order memory orderLeft,
        bytes memory signatureLeft,
        LibOrder.Order memory orderRight,
        bytes memory signatureRight
    ) external payable {
        validate(orderLeft, signatureLeft);
        validate(orderRight, signatureRight);

        matchMakers(orderLeft, orderRight);
        matchAssets(orderLeft, orderRight);
        matchTokens(orderLeft, orderRight);
        matchAmounts(orderLeft, orderRight);

        doTransfers(orderLeft);
    }

    function matchMakers(LibOrder.Order memory orderLeft, LibOrder.Order memory orderRight) internal pure {
        require(orderLeft.maker == orderRight.taker, "orderLeft.maker verification failed");
        require(orderRight.maker == orderLeft.taker, "orderRight.maker verification failed");
    }

    function matchAssets(LibOrder.Order memory orderLeft, LibOrder.Order memory orderRight) internal pure {
        require(orderLeft.makeAsset.assetType.assetClass == LibAsset.ERC20_ASSET_CLASS, "Claimer asset type should be ERC20");
        require(orderLeft.takeAsset.assetType.assetClass == LibERC721LazyMint.ERC721_LAZY_ASSET_CLASS, "Claimer sould claim ERC721");

        require(orderRight.makeAsset.assetType.assetClass == LibERC721LazyMint.ERC721_LAZY_ASSET_CLASS, "Claimer sould claim ERC721");
        require(orderRight.takeAsset.assetType.assetClass == LibAsset.ERC20_ASSET_CLASS, "Claimer asset type should be ERC20");
    }

    function matchTokens(LibOrder.Order memory orderLeft, LibOrder.Order memory orderRight) internal pure {
        address leftTokenAddress = abi.decode(orderLeft.makeAsset.assetType.data, (address));
        address leftNFTAddress = abi.decode(orderLeft.takeAsset.assetType.data, (address));
        address rightTokenAddress = abi.decode(orderRight.takeAsset.assetType.data, (address));
        address rightNFTAddress = abi.decode(orderRight.makeAsset.assetType.data, (address));

        require(leftTokenAddress == rightTokenAddress, "Orders assets don't match");
        require(leftNFTAddress == rightNFTAddress, "Orders assets don't match");
    }

    function matchAmounts(LibOrder.Order memory orderLeft, LibOrder.Order memory orderRight) internal pure {
        (, LibERC721LazyMint.Mint721Data memory leftData) = abi.decode(orderLeft.takeAsset.assetType.data, (address, LibERC721LazyMint.Mint721Data));
        (, LibERC721LazyMint.Mint721Data memory rightData) = abi.decode(orderRight.makeAsset.assetType.data, (address, LibERC721LazyMint.Mint721Data));

        require(leftData.tokenId == rightData.tokenId, "Token Ids dont match");
        require(orderLeft.makeAsset.value == orderRight.takeAsset.value, "Order values don't match");
    }

    uint256[49] private __gap;
}