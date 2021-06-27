// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.8.5;

import './interfaces/ICryptoChangeDexV1.sol';
import './libraries/CryptoChangeV1Library.sol';
import './libraries/CryptoChangeV1PriceFeeds.sol';
import './libraries/CryptoChangeV1Validator.sol';
import './libraries/TransferHelper.sol';
import './libraries/Util.sol';
import '../price-feeds/PriceFeeds.sol';

contract CryptoChangeDexV1 is ICryptoChangeDexV1, PriceFeeds {
    /**
     * @dev The user can send Ether and get tokens in exchange.
     *
     * The ETH balance of the contract is auto-updated.
     */
    function swapExactEthForTokens(address[] calldata path) public payable returns (uint256[2] memory amounts) {
        PriceFeed[2] memory priceFeeds =
            CryptoChangeV1PriceFeeds.getPriceFeeds(
                ethPriceFeed,
                tokenPriceFeeds,
                path,
                Util.SwapType.ExactEthForTokens
            );
        amounts = CryptoChangeV1Library.getAmounts(0, Util.SwapType.ExactEthForTokens, priceFeeds);
        CryptoChangeV1Validator.validateSwapExactEthForTokens(amounts, path);

        uint256 amountIn = amounts[0];
        uint256 amountOut = amounts[1];

        TransferHelper.safeTransfer(path[0], msg.sender, amountOut);

        emit ExactEthForTokensSwapped(amountIn, amountOut);
    }

    /**
     * @dev The user swap tokens and get Ether in exchange.
     */
    function swapExactTokensForEth(uint256 amount, address[] calldata path) public returns (uint256[2] memory amounts) {
        PriceFeed[2] memory priceFeeds =
            CryptoChangeV1PriceFeeds.getPriceFeeds(
                ethPriceFeed,
                tokenPriceFeeds,
                path,
                Util.SwapType.ExactTokensForEth
            );
        amounts = CryptoChangeV1Library.getAmounts(amount, Util.SwapType.ExactTokensForEth, priceFeeds);
        CryptoChangeV1Validator.validateSwapExactTokensForEth(amounts, path);

        uint256 amountIn = amounts[0];
        uint256 amountOut = amounts[1];

        TransferHelper.safeTransferFrom(path[0], msg.sender, address(this), amountIn);
        TransferHelper.safeTransferEth(msg.sender, amountOut);

        emit ExactTokensForEthSwapped(amountIn, amountOut);
    }

    /**
     * @dev The user swaps a token for another.
     */
    function swapExactTokensForTokens(uint256 amount, address[] calldata path)
        public
        returns (uint256[2] memory amounts)
    {
        PriceFeed[2] memory priceFeeds =
            CryptoChangeV1PriceFeeds.getPriceFeeds(
                ethPriceFeed,
                tokenPriceFeeds,
                path,
                Util.SwapType.ExactTokensForTokens
            );
        amounts = CryptoChangeV1Library.getAmounts(amount, Util.SwapType.ExactTokensForTokens, priceFeeds);
        CryptoChangeV1Validator.validateSwapExactTokensForTokens(amounts, path);

        uint256 amountIn = amounts[0];
        uint256 amountOut = amounts[1];

        TransferHelper.safeTransferFrom(path[0], msg.sender, address(this), amountIn);
        TransferHelper.safeTransfer(path[1], msg.sender, amountOut);

        emit ExactTokensForTokensSwapped(msg.sender, amountIn, amountOut);
    }

    function depositETH() external payable {
        emit EthDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Any user can call this.
     */
    function isAdminAccount() public view returns (bool) {
        return admins[msg.sender] != 0 || owner() == msg.sender;
    }
}