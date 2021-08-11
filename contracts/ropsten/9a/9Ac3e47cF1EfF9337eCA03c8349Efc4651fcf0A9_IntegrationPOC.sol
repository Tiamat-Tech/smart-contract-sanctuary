// SPDX-License-Identifier: GPL-3.0

// https://ropsten.etherscan.io/address/0xb63C30f0Ca47e99626249c2bf1a4A89f18728938

// An Implimentation of https://docs.euler.xyz/developers/integration-guide

pragma solidity ^0.8.0;


import "./Interfaces2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract IntegrationPOC is Ownable {

    address immutable EULER_MAINNET;

    IEulerMarkets immutable markets;

    constructor ( address _euler_mainnet, address _euler_markets ) public onlyOwner {

        EULER_MAINNET = _euler_mainnet;
        markets = IEulerMarkets(_euler_markets);


    } 

    /*
    // Use the markets module:
    IEulerMarkets markets = IEulerMarkets(0x9E02f3a8567587D27d7EB1D087408D062b4c6a1c);

    address EULER_MAINNET = 0x36C02dA8a0983159322a80FFE9F24b1acfF8B570; */



    // Deposit asset
    function depositAsset(address underlying, uint subAccountId, uint amount) external {

        // Approve the main euler contract to pull your tokens:
        IERC20(underlying).approve(EULER_MAINNET, type(uint).max);

        
        // Get the eToken address using the markets module:
        IEulerEToken eToken = IEulerEToken(markets.underlyingToEToken(underlying));

        // Deposit number of underlying tokens (assuming 18 decimal places)
        // The "subAccountId" argument refers to the sub-account you are depositing to.
        eToken.deposit(subAccountId, amount);
    }

    // get balance of EToken
    function getBalanceOfEToken(address underlying) public view returns (uint) {

        IEulerEToken eToken = IEulerEToken(markets.underlyingToEToken(underlying));

        uint balance = eToken.balanceOf(address(this));

        // To Do..
        // -> internal book-keeping value that doesn't increase over time

        return balance;

    }

    // Get balance of underlying
    function getBalanceOfUnderlying(address underlying) public returns (uint) {

        IEulerEToken eToken = IEulerEToken(markets.underlyingToEToken(underlying));

        uint balanceOfUnderlying = eToken.balanceOfUnderlying(address(this));
        
        return  balanceOfUnderlying;

    }
 
    // Withdraw underlying with interest:  
    function withdraw(address underlying, uint subAccountId, uint amount) external {

        IEulerEToken eToken = IEulerEToken(markets.underlyingToEToken(underlying));

        eToken.withdraw(subAccountId, type(uint).max);
    }


    /// Borrow and repay
    // Use the markets module:
    // IEulerMarkets markets = IEulerMarkets(EULER_MAINNET_MARKETS);

    // Deposit Collateral
    function depositCollateral(address collateral, uint subAccountId, uint amount) external {

        // Approve, get eToken addr, and deposit:
        IERC20(collateral).approve(EULER_MAINNET, type(uint).max);

        IEulerEToken collateralEToken = IEulerEToken(markets.underlyingToEToken(collateral));

        collateralEToken.deposit(subAccountId,amount); // amount = 100e18

        // Enter the collateral market (collateral's address, *not* the eToken address):
        markets.enterMarket(subAccountId, collateral);
    }

    // Borrow
    function borrow(address borrowed, uint subAccountId, uint amount) external {

        // Get the dToken address of the borrowed asset:
        IEulerDToken borrowedDToken = IEulerDToken(markets.underlyingToDToken(borrowed));

        borrowedDToken.borrow(subAccountId, amount); // amount =2e18
    }

    // Get balance of borrowed tokens

    function getBalanceOfBorrowedToken(address borrowed) external returns(uint) {

        IEulerDToken borrowedDToken = IEulerDToken(markets.underlyingToDToken(borrowed));

        uint balanceOfBorrowed = borrowedDToken.balanceOf(address(this));

        return balanceOfBorrowed;

        // To Do..
        // ... but check back next block to see it go up
    }

    // Repay borrowed token
    function repay(address borrowed, uint subAccountId, uint amount) external {

        IEulerDToken borrowedDToken = IEulerDToken(markets.underlyingToDToken(borrowed));

        IERC20(borrowed).approve(EULER_MAINNET, type(uint).max);

        borrowedDToken.repay(subAccountId, type(uint).max);

    }

}