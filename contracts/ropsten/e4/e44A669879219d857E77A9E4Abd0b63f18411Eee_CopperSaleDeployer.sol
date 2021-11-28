pragma solidity ^0.5.5;

import "./CopperToken.sol";
import "./CopperSale.sol";



contract CopperSaleDeployer {
    address public token_sale_address;
    address public token_address;

    constructor() public {
        CopperToken token = new CopperToken("peg63.546u", "CU", 18);
        token_address = address(token);
        CopperSale token_sale = new CopperSale(20000, 0xcD0A862d78D79Da9F0D26ad2E9A5B8C12AB6dA81, token, 1638088200, 1638095400);
        token_sale_address = address(token_sale);
        token.addMinter(token_sale_address);
        token.renounceMinter();
    }
}