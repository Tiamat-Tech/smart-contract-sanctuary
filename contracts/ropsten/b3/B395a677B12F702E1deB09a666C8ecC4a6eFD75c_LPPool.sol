// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILPPool {
    //================== Callers ==================//
    function wexos() external view returns (IERC20);

    function startTime() external view returns (uint256);

    function totalReward() external view returns (uint256);

    function earned(address account) external view returns (uint256);

    //================== Transactors ==================//

    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function exit() external;

    function getReward() external;
}