pragma solidity ^0.5.5;

import "./CopperToken.sol";
import "./CopperSale.sol";



contract CopperSaleDeployer {
    address public token_sale_address;
    address public token_address;

    constructor() public {
        CopperToken token = new CopperToken("peg63.546ua", "Cu", 18);
        token_address = address(token);
        CopperSale token_sale = new CopperSale(2000, 0x76a468E65a2B5EF3Eb00471289aae3b29b6fcB34, token, now, now + 7 days);
        token_sale_address = address(token_sale);
        token.addMinter(token_sale_address);
        token.renounceMinter();
    }
}