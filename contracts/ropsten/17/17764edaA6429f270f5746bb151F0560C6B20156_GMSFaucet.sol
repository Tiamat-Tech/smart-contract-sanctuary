// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./libraries/SafeERC20.sol";

contract GMSFaucet {
    using SafeERC20 for IERC20;

    address private owner;
    address[] public stableMocks;

    constructor(address _owner, address[] memory _stableCoins) {
        require(_owner != address(0), "GMSFouset: Owner is a zero address");
        owner = _owner;
        stableMocks = _stableCoins;
    }

    function midasTouch(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            for (uint256 j = 0; j < stableMocks.length; j++) {
                address stableCoin = address(stableMocks[j]);
                uint8 decimals = IERC20(stableCoin).safeDecimals();
                uint256 stableCoinUnits = 15000 * (10**(decimals));

                IERC20(stableCoin).safeTransfer(address(accounts[i]), stableCoinUnits);
            }

            payable(address(accounts[i])).transfer(100000000000000000);
        }
    }

    function recoverErc20(address token) external onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        if (amount > 0) {
            IERC20(token).safeTransfer(owner, amount);
        }
    }

    function recoverEth() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "GMSSeedSaleTest: Only for contract Owner");
        _;
    }

    receive() external payable {}
}