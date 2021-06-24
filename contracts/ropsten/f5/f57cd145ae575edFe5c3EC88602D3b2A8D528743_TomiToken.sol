// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract TomiToken is ERC20Burnable {
    // 1500 M total supply
    uint256 private TOTAL_SUPPLY = 1500 * 10**(6 + 18);
    uint256 private COMMUNITY_SUPPLY_AT_LAUCH = 250 * 10**(6 + 18);
    uint256 private DEVELOPMENT_SUPPLY = 250 * 10**(6 + 18);
    uint256 private LIQUIDITY_SUPPLY = 750 * 10**(6 + 18);
    uint256 private OWNER_SUPPLY = 250 * 10**(6 + 18);

    // 150M 2nd year – June 25th, 2022
    uint256 private COMMUNITY_LOCKER1_SUPPLY = 150 * 10**(6 + 18);
    // 100M 3rd year – June 25th 2023
    uint256 private COMMUNITY_LOCKER2_SUPPLY = 100 * 10**(6 + 18);

    uint8 private constant OWNER_INDEX = 0;
    uint8 private constant COMMUNITY_INDEX = 1;
    uint8 private constant DEVELOPMENT_INDEX = 2;
    uint8 private constant LIQUIDITY_INDEX = 3;
    uint8 private constant COMMUNITY_LOCKER1_INDEX = 4;
    uint8 private constant COMMUNITY_LOCKER2_INDEX = 5;
    uint8 private constant INVALID_INDEX = 6;

    uint256[6] private _pools_amount = [
        OWNER_SUPPLY,
        COMMUNITY_SUPPLY_AT_LAUCH,
        DEVELOPMENT_SUPPLY,
        LIQUIDITY_SUPPLY,
        COMMUNITY_LOCKER1_SUPPLY,
        COMMUNITY_LOCKER2_SUPPLY
    ];

    bool[6] public _minted_pool;
    address private _owner;

    constructor(
        bool all_pools_ready,
        address owner,
        address community,
        address develop,
        address liquidity
    ) public ERC20("TOMI", "TOMI") {
        _owner = owner;

        if (all_pools_ready) {
            _mint(owner, OWNER_SUPPLY);
            _minted_pool[OWNER_INDEX] = true;

            // 250 M at lauch date
            _mint(community, COMMUNITY_SUPPLY_AT_LAUCH);
            _minted_pool[COMMUNITY_INDEX] = true;

            _mint(develop, DEVELOPMENT_SUPPLY);
            _minted_pool[DEVELOPMENT_INDEX] = true;

            _mint(liquidity, LIQUIDITY_SUPPLY);
            _minted_pool[LIQUIDITY_INDEX] = true;

            _minted_pool[COMMUNITY_LOCKER1_INDEX] = false;
            _minted_pool[COMMUNITY_LOCKER2_INDEX] = false;

        } else {
            _mint(owner, TOTAL_SUPPLY);
            _minted_pool = [true, false, false, false, false, false];
        }
    }

    function addPool(uint8 pool_type, address pool_address) external {
        require(msg.sender == _owner);
        require(pool_type < INVALID_INDEX);
        require(_minted_pool[pool_type] == false);

        _transfer(_owner, pool_address, _pools_amount[pool_type]);
        _minted_pool[pool_type] = true;
    }
}