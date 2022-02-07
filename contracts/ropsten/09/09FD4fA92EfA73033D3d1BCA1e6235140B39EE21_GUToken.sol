// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract GUToken is ERC20 {
    address constant ECOSYSTEM_TOKEN_ADDRESS =
        0x8a0C5BCFcAdF9a494C3BC20ac61B6e05EfAc3036;
    address constant RESERVED_TOKEN_ADDRESS =
        0x719949b5D490E08F93AA4Fbceb5a15563ac5aa7C;
    address constant TEAM_TOKEN_ADDRESS =
        0xB4Ad2C088b4b79A7D645b02Fa1246c27885CB920;
    uint256 immutable releaseTime;
    uint256 constant FINAL_SUPPLY_AMOUNT = 10000000000 * 10**9;

    constructor() ERC20("Globally United Coin", "GU") {
        _mint(msg.sender, 1800000000 * 10**9); //mint tokens for private, closed, public
        _mint(msg.sender, 1000000000 * 10**9); //here mint tokens for reserve
        _mint(msg.sender, 2500000000 * 10**9); //here mint tokens for team
        _mint(msg.sender, 2500000000 * 10**9); //mint tokens for reserve DEX & CEX
        releaseTime = block.timestamp + 365 days;
    }

    function burnToken(uint256 burnAmount) external {
        _burn(msg.sender, burnAmount);
    }

    function releaseEcosystemToken() external {
        require(
            block.timestamp > releaseTime,
            "current time is less than release time"
        );
        require(
            totalSupply() < FINAL_SUPPLY_AMOUNT,
            "Total supply is greater than final supply"
        );

        _mint(ECOSYSTEM_TOKEN_ADDRESS, 2200000000 * 10**9);
    }

    function batchTransfer(address[] memory to, uint256[] memory amount)
        external
    {
        require(
            to.length == amount.length,
            "lengths of both array are not same"
        );
        for (uint256 i = 0; i < to.length; i++) {
            transfer(to[i], amount[i]);
        }
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }
}