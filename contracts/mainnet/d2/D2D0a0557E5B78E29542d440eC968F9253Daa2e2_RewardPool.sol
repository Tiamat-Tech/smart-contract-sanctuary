// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.6;

import {Pool} from '../treasury/Pool.sol';


contract RewardPool is Pool {

  constructor(address _admin, address[] memory _strategies)
    Pool(_admin, _strategies) {}
}