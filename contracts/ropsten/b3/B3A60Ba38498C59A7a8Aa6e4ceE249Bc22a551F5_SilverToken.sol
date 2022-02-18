pragma solidity 0.8.11;

import { ERC20 } from "../openzeppelin/ERC20.sol";

abstract contract TestToken is
    ERC20
{
    constructor(
        string memory name,
        string memory symbol
    )
        ERC20(name, symbol)
    {
        _mint(msg.sender, 1_000_000);
    }

    function decimals()
        public
        view
        virtual
        override
        returns (uint8)
    {
        return 0;
    }
}

contract BronzeToken is TestToken("BronzeToken", "BRONZE") {}

contract SilverToken is TestToken("SilverToken", "SILVER") {}

contract GoldToken is TestToken("GoldToken", "GOLD") {}