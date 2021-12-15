pragma solidity ^0.8.1;

import "ERC20Mock.sol";

contract USDTMock is ERC20Mock {
    constructor(address initialAccount, uint256 initialBalance) ERC20Mock("JetsUSDT", "USDT", initialAccount, initialBalance) {
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }
}