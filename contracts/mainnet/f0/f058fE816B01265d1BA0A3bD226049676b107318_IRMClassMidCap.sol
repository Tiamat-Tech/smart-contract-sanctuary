// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../../BaseIRMLinearKink.sol";


contract IRMClassMidCap is BaseIRMLinearKink {
    constructor(bytes32 moduleGitCommit_)
        BaseIRMLinearKink(MODULEID__IRM_CLASS__MIDCAP, moduleGitCommit_,
            // Base=0% APY,  Kink(80%)=35% APY  Max=300% APY
            0, 2767755633, 40070134595, 3435973836
        ) {}
}