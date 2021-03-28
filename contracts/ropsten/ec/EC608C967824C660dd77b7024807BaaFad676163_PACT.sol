// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "./vendors/contracts/access/Ownable.sol";
import "./vendors/contracts/DelegableToken.sol";
import "./vendors/interfaces/IDelegableERC20.sol";

// SushiToken with Governance.
contract PACT is IDelegableERC20, DelegableToken, Ownable
{
    constructor() ERC20("P2PB2B community token", "PACT") public {
        _totalSupply = 1000000000e18;

        _balances[address(0)] = _totalSupply;
    }

    uint256 AmountBasePool = 200000000e18;
    uint256 AmountReserve  = 200000000e18;
    uint256 AmountTeam     = 100000000e18;
    uint256 AmountRewards  = 200000000e18;
    uint256 AmountFarming  = 300000000e18;

    function setupBasePool(address account) external onlyOwner returns (bool) {
        require(AmountBasePool > 0, "BasePool account already setup");
        _transferWithoutAddressValidations(address(0), account, AmountBasePool);
        AmountBasePool=0;
        return true;
    }
    function setupReserve(address account) external onlyOwner returns (bool) {
        require(AmountReserve > 0, "Reserve account already setup");
        _transferWithoutAddressValidations(address(0), account, AmountReserve);
        AmountReserve=0;
        return true;
    }
    function setupTeam(address account) external onlyOwner returns (bool) {
        require(AmountTeam > 0, "Team account already setup");
        _transferWithoutAddressValidations(address(0), account, AmountTeam);
        AmountTeam=0;
        return true;
    }
    function setupRewards(address account) external onlyOwner returns (bool) {
        require(AmountRewards > 0, "Rewards account already setup");
        _transferWithoutAddressValidations(address(0), account, AmountRewards);
        AmountRewards=0;
        return true;
    }
    function setupFarming(address account) external onlyOwner returns (bool) {
        require(AmountFarming > 0, "Farming account already setup");
        _transferWithoutAddressValidations(address(0), account, AmountFarming);
        AmountFarming=0;
        return true;
    }
    
    function burn(uint amount) external onlyOwner returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }
}