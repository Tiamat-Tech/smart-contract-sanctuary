// SPDX-License-Identifier: MIT
pragma solidity ^0.6.7;

import "../strategy-basis-farm-base-v2.sol";

contract StrategyBasisBasDaiLpV3 is StrategyBasisFarmBaseV2 {
    // Token addresses
    address public uni_bas_dai_lp = 0x3E78F2E7daDe07ea685F8612F00477FD97162F1e;

    constructor(
        address _governance,
        address _strategist,
        address _controller,
        address _timelock
    )
        public
        StrategyBasisFarmBaseV2(
            bas,
            0x818F83333244bA4BB72Dab0b60b1901158402f2E, // Basis V2 Distribution
            2, // Basis Staking PID for BAS-DAI lp
            uni_bas_dai_lp,
            _governance,
            _strategist,
            _controller,
            _timelock
        )
    {}

    // **** Views ****

    function getName() external override pure returns (string memory) {
        return "StrategyBasisV3BasDaiLp";
    }
}