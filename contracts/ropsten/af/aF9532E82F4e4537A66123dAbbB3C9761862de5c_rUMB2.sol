//SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import "./interfaces/rUMB.sol";
import "./interfaces/OnDemandToken.sol";

contract rUMB2 is rUMB, OnDemandToken {
     constructor (
        address _owner,
        uint256 _maxAllowedTotalSupply,
        uint256 _swapDuration,
        string memory _name,
        string memory _symbol
    )

    rUMB(_owner, address(0), 0, _maxAllowedTotalSupply, _swapDuration, _name, _symbol) {
    }

    function mint(address _holder, uint256 _amount)
        external
        override(MintableToken, OnDemandToken)
        onlyOwnerOrMinter()
        assertMaxSupply(_amount)
    {
        require(_amount != 0, "zero amount");

        _mint(_holder, _amount);
    }
}