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

        cDaiAddress = 0xbc689667C13FB2a04f09272753760E38a95B998C;
        daiAddress = 0xaD6D458402F60fD3Bd25163575031ACDce07538D;

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
        // Comptroller comptroller = Comptroller(cCompotrollerAddress);
        
         // Create a reference to the corresponding cToken contract, like cDAI
        CErc20 cToken = CErc20(cTokenAddress);

        // Create a reference to the underlying asset contract, like DAI.
        Erc20 underlying = Erc20(cUnderlyingAddress);

        // Amount of current exchange rate from cToken to underlying
        uint256 exchangeRateMantissa = cToken.exchangeRateCurrent();
        emit Log("Exchange Rate (scaled up): ", exchangeRateMantissa);

        // Amount added to you supply balance this block
        uint256 supplyRateMantissa = cToken.supplyRatePerBlock();
        emit Log("Supply Rate: (scaled up)", supplyRateMantissa);

        uint256 _numTokensToSupply = 1;

        // Approve transfer on the ERC20 contract
        underlying.approve(cTokenAddress, _numTokensToSupply);
        emit Log("Underlying approved", _numTokensToSupply);

        // Mint cTokens
        uint mintResult = cToken.mint(_numTokensToSupply);
        emit Log("Mint successful", mintResult);

        return mintResult;
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