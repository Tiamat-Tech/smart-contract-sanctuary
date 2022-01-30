// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenDummy is ERC20 {
    uint256 private constant SUPPLY = 20000000 * 10**6;

    constructor(address distributor) ERC20("Dummy USDT", "USDT") {
        _mint(distributor, SUPPLY);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}