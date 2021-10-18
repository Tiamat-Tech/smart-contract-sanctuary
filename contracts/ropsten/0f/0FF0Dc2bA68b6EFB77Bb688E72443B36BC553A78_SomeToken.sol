// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";
import '@openzeppelin/contracts/math/SafeMath.sol';

contract SomeToken is ERC20PresetMinterPauser {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;

    constructor() ERC20PresetMinterPauser("SomeToken", "ST") public {}

    /**
     * @dev Remove Transfer event emit to provoke error
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
    }
}