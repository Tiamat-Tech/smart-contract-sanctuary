pragma solidity 0.5.11;

import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract TomiToken is ERC20Detailed, ERC20Burnable {
    // 1500 M total supply
    uint256 private TOTAL_SUPPLY = 1500 * 10**(6 + 18);
    uint256 private COMMUNITY_SUPPLY_AT_LAUCH = 250 * 10**(6 + 18);
    uint256 private DEVELOPMENT_SUPPLY = 250 * 10**(6 + 18);
    uint256 private LIQUIDITY_SUPPLY = 750 * 10**(6 + 18);
    uint256 private OWNER_SUPPLY = 250 * 10**(6 + 18);

    uint8 private constant OWNER_INDEX = 0;
    uint8 private constant COMMUNITY_INDEX = 1;
    uint8 private constant DEVELOPMENT_INDEX = 2;
    uint8 private constant LIQUIDITY_INDEX = 3;
    uint8 private constant INVALID_INDEX = 4;

    uint256[4] private _pools_amount = [
        OWNER_SUPPLY,
        COMMUNITY_SUPPLY_AT_LAUCH,
        DEVELOPMENT_SUPPLY,
        LIQUIDITY_SUPPLY
    ];

    bool[4] public _minted_pool;
    address private _owner;

    constructor(
        bool all_pools_ready,
        address owner,
        address community,
        address develop,
        address liquidity
    ) public ERC20Detailed("TM TEST", "TMT", 18) {
        _owner = owner;

        if (all_pools_ready) {
            _mint(owner, OWNER_SUPPLY);
            _minted_pool[OWNER_INDEX] = true;

            // 250 M at lauch date
            _mint(community, COMMUNITY_SUPPLY_AT_LAUCH);
            _minted_pool[COMMUNITY_INDEX] = true;
            // 150M 2nd year – June 25th, 2022 in owner address
            // 100M 3rd year – June 25th 2023 in owner address

            _mint(develop, DEVELOPMENT_SUPPLY);
            _minted_pool[DEVELOPMENT_INDEX] = true;

            _mint(liquidity, LIQUIDITY_SUPPLY);
            _minted_pool[LIQUIDITY_INDEX] = true;
        } else {
            _mint(owner, TOTAL_SUPPLY);
            _minted_pool = [true, false, false, false];
        }
    }

    function addPool(uint8 pool_type, address pool_address) external {
        require(msg.sender == _owner);
        require(pool_type > OWNER_INDEX);
        require(pool_type < INVALID_INDEX);
        require(_minted_pool[pool_type] == false);
        _transfer(_owner, pool_address, _pools_amount[pool_type]);
    }
}