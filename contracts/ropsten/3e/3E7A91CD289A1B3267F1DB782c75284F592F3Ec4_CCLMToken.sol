// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0-rc.0 (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

//import "ER/ERC20Detailed.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract CCLMToken is ERC20 {
    // using SafeMath for uint256;
    uint256 constant finalSupply = 100 * 10**6 * 10**9;
    uint256 deployTime;
    address constant tokenForCompany =
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address constant tokenForFounder =
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    uint256 burnRateStartTime;
    uint256 constant burnAmount = 10**6 * 10**9;

    constructor() ERC20("Carbon Clean Coin", "CCLM") {
        _mint(msg.sender, 100000000 * 10**9);
        deployTime = block.timestamp + 90 days;
        burnRateStartTime = block.timestamp + 365 days;
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    function burnRate() external {
        require(block.timestamp > burnRateStartTime);

        _burn(msg.sender, burnAmount);
    }

    function releaseToken() external {
        require(block.timestamp > deployTime);
        _mint(tokenForCompany, 59000000 * 10**9);
        _mint(tokenForFounder, 28000000 * 10**9);
    }
}