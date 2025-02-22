// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';

import '../utils/Operator.sol';

contract MockwBTC is ERC20Burnable, Operator {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 constant MINT_AMOUNT = 10000 * 10**18;

    /**
     * @notice Constructs the Mock wBTC token for testing ERC-20 contract.
     */
    constructor() ERC20('wBTC', 'wBTC') {
        _mint(msg.sender, MINT_AMOUNT);
    }

    /**
     * @notice Operator mints dino gold to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of dino gold to mint to
     * @return whether the process has been done
     */
    function mint(address recipient_, uint256 amount_)
        public
        onlyOperator
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }
}