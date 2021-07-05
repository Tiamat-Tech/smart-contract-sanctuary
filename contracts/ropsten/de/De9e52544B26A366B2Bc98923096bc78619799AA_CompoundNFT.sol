// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.7.6;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseERC20Vault} from "../BaseERC20Vault.sol";

interface CToken {
    function mint() external payable;

    function mint(uint256) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function redeem(uint) external returns (uint);

    function redeemUnderlying(uint) external returns (uint);

    function borrow(uint256) external returns (uint256);

    function borrowRatePerBlock() external view returns (uint256);

    function borrowBalanceCurrent(address) external returns (uint256);

    function repayBorrow() external payable;

    function repayBorrow(uint256) external returns (uint256);
}

interface Comptroller {
    function markets(address) external returns (bool, uint256);

    function enterMarkets(address[] calldata)
        external
        returns (uint256[] memory);

    function getAccountLiquidity(address)
        external
        view
        returns (uint256, uint256, uint256);
}

interface PriceFeed {
    function getUnderlyingPrice(address cToken) external view returns (uint);
}

contract CompoundNFT is BaseERC20Vault {
    event Log(string, uint256);

    function supplyEthToCompound(address payable _cEtherContract)
        public
        payable
        returns (bool)
    {
        // Create a reference to the corresponding cToken contract
        CToken cToken = CToken(_cEtherContract);

        // Amount of current exchange rate from cToken to underlying
        uint256 exchangeRateMantissa = cToken.exchangeRateCurrent();
        emit Log("Exchange Rate (scaled up by 1e18): ", exchangeRateMantissa);

        // Amount added to you supply balance this block
        uint256 supplyRateMantissa = cToken.supplyRatePerBlock();
        emit Log("Supply Rate: (scaled up by 1e18)", supplyRateMantissa);

        cToken.mint{value: msg.value}();
        return true;
    }

    function supplyErc20ToCompound(
        address _erc20Contract,
        address _cErc20Contract,
        uint256 _numTokensToSupply
    ) public returns (uint) {
        // Create a reference to the underlying asset contract, like DAI.
        IERC20 underlying = IERC20(_erc20Contract);

        // Create a reference to the corresponding cToken contract, like cDAI
        CToken cToken = CToken(_cErc20Contract);

        // Amount of current exchange rate from cToken to underlying
        uint256 exchangeRateMantissa = cToken.exchangeRateCurrent();
        emit Log("Exchange Rate (scaled up): ", exchangeRateMantissa);

        // Amount added to you supply balance this block
        uint256 supplyRateMantissa = cToken.supplyRatePerBlock();
        emit Log("Supply Rate: (scaled up)", supplyRateMantissa);

        // Approve transfer on the ERC20 contract
        underlying.approve(_cErc20Contract, _numTokensToSupply);

        // Mint cTokens
        uint mintResult = cToken.mint(_numTokensToSupply);
        return mintResult;
    }

    function redeemCTokens(
        uint256 amount,
        bool redeemType,
        address _cTokenContract
    ) public returns (bool) {
        // Create a reference to the corresponding cToken contract, like cDAI
        CToken cToken = CToken(_cTokenContract);

        // `amount` is scaled up, see decimal table here:
        // https://compound.finance/docs#protocol-math

        uint256 redeemResult;

        if (redeemType == true) {
            // Retrieve your asset based on a cToken amount
            redeemResult = cToken.redeem(amount);
        } else {
            // Retrieve your asset based on an amount of the asset
            redeemResult = cToken.redeemUnderlying(amount);
        }

        // Error codes are listed here:
        // https://compound.finance/developers/ctokens#ctoken-error-codes
        emit Log("If this is not 0, there was an error", redeemResult);

        return true;
    }

    function borrowErc20(
        address payable _cEtherAddress,
        address _comptrollerAddress,
        address _priceFeedAddress,
        address _cTokenAddress,
        uint _underlyingDecimals,
        uint256 numUnderlyingToBorrow
    ) public payable returns (uint256) {
        CToken cEth = CToken(_cEtherAddress);
        Comptroller comptroller = Comptroller(_comptrollerAddress);
        PriceFeed priceFeed = PriceFeed(_priceFeedAddress);
        CToken cToken = CToken(_cTokenAddress);

        // Supply ETH as collateral, get cETH in return
        cEth.mint{value: msg.value}();

        // Enter the ETH market so you can borrow another type of asset
        address[] memory cTokens = new address[](1);
        cTokens[0] = _cEtherAddress;
        uint256[] memory errors = comptroller.enterMarkets(cTokens);
        if (errors[0] != 0) {
            revert("Comptroller.enterMarkets failed.");
        }

        // Get my account's total liquidity value in Compound
        (uint256 error, uint256 liquidity, uint256 shortfall) = comptroller.getAccountLiquidity(address(this));
        if (error != 0) {
            revert("Comptroller.getAccountLiquidity failed.");
        }
        require(shortfall == 0, "account underwater");
        require(liquidity > 0, "account has excess collateral");

        // Get the underlying price in USD from the Price Feed,
        // so we can find out the maximum amount of underlying we can borrow.
        uint256 underlyingPrice = priceFeed.getUnderlyingPrice(_cTokenAddress);
        uint256 maxBorrowUnderlying = liquidity / underlyingPrice;

        // Borrowing near the max amount will result
        // in your account being liquidated instantly
        emit Log("Maximum underlying Borrow (borrow far less!)", maxBorrowUnderlying);

        // Borrow, check the underlying balance for this contract's address
        cToken.borrow(numUnderlyingToBorrow * 10** _underlyingDecimals);

        // Get the borrow balance
        uint256 borrows = cToken.borrowBalanceCurrent(address(this));
        emit Log("Current underlying borrow amount", borrows);

        return borrows;
    }

    function repayBorrowedERC20(
        address _erc20Address,
        address _cErc20Address,
        uint256 amount
    ) public returns (bool) {
        IERC20 underlying = IERC20(_erc20Address);
        CToken cToken = CToken(_cErc20Address);

        underlying.approve(_cErc20Address, amount);
        uint256 error = cToken.repayBorrow(amount);

        require(error == 0, "CToken.repayBorrow Error");
        return true;
    }

    function borrowEth(
        address payable _cEtherAddress,
        address _comptrollerAddress,
        address _cTokenAddress,
        address _underlyingAddress,
        uint256 _underlyingToSupplyAsCollateral,
        uint256 numWeiToBorrow
    ) public returns (uint) {
        CToken cEth = CToken(_cEtherAddress);
        Comptroller comptroller = Comptroller(_comptrollerAddress);
        CToken cToken = CToken(_cTokenAddress);
        IERC20 underlying = IERC20(_underlyingAddress);

        // Approve transfer of underlying
        underlying.approve(_cTokenAddress, _underlyingToSupplyAsCollateral);

        // Supply underlying as collateral, get cToken in return
        uint256 error = cToken.mint(_underlyingToSupplyAsCollateral);
        require(error == 0, "CToken.mint Error");

        // Enter the market so you can borrow another type of asset
        address[] memory cTokens = new address[](1);
        cTokens[0] = _cTokenAddress;
        uint256[] memory errors = comptroller.enterMarkets(cTokens);
        if (errors[0] != 0) {
            revert("Comptroller.enterMarkets failed.");
        }

        // Get my account's total liquidity value in Compound
        (uint256 error2, uint256 liquidity, uint256 shortfall) = comptroller.getAccountLiquidity(address(this));
        if (error2 != 0) {
            revert("Comptroller.getAccountLiquidity failed.");
        }
        require(shortfall == 0, "account underwater");
        require(liquidity > 0, "account has excess collateral");

        // Borrowing near the max amount will result
        // in your account being liquidated instantly
        emit Log("Maximum ETH Borrow (borrow far less!)", liquidity);

        // Borrow, then check the underlying balance for this contract's address
        cEth.borrow(numWeiToBorrow);

        uint256 borrows = cEth.borrowBalanceCurrent(address(this));
        emit Log("Current ETH borrow amount", borrows);

        return borrows;
    }

    function repayBorrowedETH(address _cEtherAddress, uint256 amount)
        public
        returns (bool)
    {
        CToken cEth = CToken(_cEtherAddress);
        cEth.repayBorrow{value: amount}();
        return true;
    }

}