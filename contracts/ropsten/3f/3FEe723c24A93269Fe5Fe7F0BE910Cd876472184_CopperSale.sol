pragma solidity ^0.5.5;

/////////////////////////////////////////////////////
//////////////////////// ICO ////////////////////////
/////////////////////////////////////////////////////
//
// **************************************************
// Token:
// ==================================================
// Name        : peg63.546u Copper
// Symbol      : CU
// Total supply: Will be set after the Crowdsale
// ==================================================
//
//
// **************************************************
// Crowdsale:
// ==================================================
// Token : peg63.546u Copper
// Price : 0.00002
// Start : 15 December 2021 00:00 UTC±0
// End   : 22 December 2021 00:00 UTC±0
// Wallet: 0xcD0A862d78D79Da9F0D26ad2E9A5B8C12AB6dA81
// ==================================================


import "./CopperToken.sol";
import "./CopperSale.sol";



contract CopperSaleDeployer {
    address public token_address;
    address public token_sale_address;

    constructor() public {
        CopperToken token = new CopperToken();
        token_address = address(token);
        CopperSale token_sale = new CopperSale(50000, 0xcD0A862d78D79Da9F0D26ad2E9A5B8C12AB6dA81, token, 1638784200, 1639129800);
        token_sale_address = address(token_sale);
        token.addMinter(token_sale_address);
        token.renounceMinter();
    }
}