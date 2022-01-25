// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Upgradeable.sol";

contract FCT is Upgradeable {

    function initialize() public initializer {
        __Context_init_unchained();  
        __Ownable_init_unchained();
        __FCT_init_unchained();
    }

    function __FCT_init_unchained() internal onlyInitializing {
        _name = "FCT";
        _symbol = "FCT";
        _decimals = 18;

        _tTotal = 10 * 10**9 * 10**18;
        _rTotal = (MAX - (MAX % _tTotal));
        _maxFee = 10**3;

        _maxTxAmount = 5000 * 10**6 * 10**18;

        _burnAddress = 0x000000000000000000000000000000000000dEaD;
        _initializerAccount = _msgSender();

        _rOwned[_initializerAccount] = _rTotal;

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        __FCT_tiers_init();

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function __FCT_tiers_init() internal onlyInitializing {
        _defaultFees = _addTier(200, 300, 500, address(0), address(0));
    }
}