// SPDX-License-Identifier: Bityield
pragma solidity 0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import "./bases/v2/IndexBase.sol";

import { Comptroller, PriceFeed, Erc20, CErc20, CEth } from "./interfaces/compound/v2/main.sol";

contract IndexV2 is IndexBaseV2, ERC20 {
    IUniswapV2Router02 private uniswapRouter;
    IUniswapV2Factory  private uniswapFactory;

    address internal cEtherAddress;
    address internal cCompotrollerAddress;
    address internal cTokenAddress;
    address internal cUnderlyingAddress;

    address internal cDaiAddress;
    address internal daiAddress;

    /* ============ Events ================= */
    event EnterMarket(
        address indexed from_,
        uint amountDeposited_,
        uint cTokens_,
        uint currentBlock_
    );

    event ExitMarket(
        address indexed from_,
        uint amountWithdrawn_,
        uint cTokens_,
        uint currentBlock_
    );

    event Log(
        string _message, 
        uint256 _amount
    );

    /* ============ Constructor ============ */
    constructor(
        string memory _name,
        string memory _symbol
    )
        public
        ERC20(_name, _symbol)
    {
        owner = msg.sender;

        cDaiAddress = 0x6D7F0754FFeb405d23C51CE938289d4835bE3b14;
        daiAddress = 0x1207e7D4e82Bd98c18BA79bA80160F0816420E4d;

        cEtherAddress = 0xd6801a1DfFCd0a410336Ef88DeF4320D6DF1883e;
        cCompotrollerAddress = 0x2EAa9D77AE4D8f9cdD9FAAcd44016E746485bddb;
        cTokenAddress = cDaiAddress;
        cUnderlyingAddress = daiAddress;
    }

    // enterMarket; is the main entry point to this contract. It takes msg.value and splits
    // to the allocation ceilings in wei. Any funds not used are returned to the sender
    function enterMarket()
        external
        payable
        returns (uint)
    {
        // CEth cEth = CEth(cEtherAddress);
        Comptroller comptroller = Comptroller(cCompotrollerAddress);
        CErc20 cToken = CErc20(cTokenAddress);
        Erc20 underlying = Erc20(cUnderlyingAddress);

        uint256 _underlyingToSupplyAsCollateral = 25;

        // Approve transfer of underlying
        underlying.approve(cTokenAddress, _underlyingToSupplyAsCollateral);
        emit Log("cToken approve success", _underlyingToSupplyAsCollateral);

        // Mint the appropriate cTokens
        uint256 error = cToken.mint(_underlyingToSupplyAsCollateral);
        require(error == 0, "CErc20.mint Error");
        emit Log("cToken mint success", _underlyingToSupplyAsCollateral);

        // Enter the market so you can borrow another type of asset
        address[] memory cTokens = new address[](1);
        cTokens[0] = cTokenAddress;

        uint256[] memory errors = comptroller.enterMarkets(cTokens);
        if (errors[0] != 0) {
            revert("Comptroller.enterMarkets failed");
        }
        emit Log("Comptroller enterMarkets success", errors[0]);

        return 0;

        // // Get my account's total liquidity value in Compound
        // (uint256 error2, uint256 liquidity, uint256 shortfall) = comptroller
        //     .getAccountLiquidity(address(this));
        // if (error2 != 0) {
        //     revert("Comptroller.getAccountLiquidity failed");
        // }
        // require(shortfall == 0, "account underwater");
        // require(liquidity > 0, "account has excess collateral");

        // emit Log("Maximum ETH Borrow (borrow far less!)", liquidity);

        // // Get the collateral factor for our collateral
        // (, uint collateralFactorMantissa) = comptroller.markets(cTokenAddress);
        // emit Log("Collateral Factor", collateralFactorMantissa);

        // // Get the amount of ETH added to your borrow each block
        // uint borrowRateMantissa = cToken.borrowRatePerBlock();
        // emit Log("Current ETH Borrow Rate", borrowRateMantissa);

        // // Borrow a fixed amount of ETH below our maximum borrow amount
        // uint256 numWeiToBorrow = 20000000000000000; // 0.02 ETH

        // // Borrow, then check the underlying balance for this contract's address
        // cEth.borrow(numWeiToBorrow);

        // uint256 borrows = cEth.borrowBalanceCurrent(address(this));
        // emit Log("Current ETH borrow amount", borrows);

        // return borrows;
    }

    function exitMarket()
        external
        returns (bool)
    {
        CEth cEth = CEth(cEtherAddress);
        cEth.repayBorrow{value: address(this).balance}();
        return true;
    }

    // receive; required to accept ether
    receive()
        external
        payable
    {}

    function custodialWithdraw()
        public
    {
        require(msg.sender == owner, "cannot withdraw if not owner");

        (bool success,) = msg.sender.call{ value: address(this).balance }("");
        require(success, "custodialWithdraw; failed");
    }
}