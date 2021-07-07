pragma solidity ^0.8.4;

interface ISnailPool {
    function getPoolInfo() external view returns (uint256 liq, bool isCitadel);
    function lock(uint256 collateral, address whose, uint256 posId) external;
    function unlock(uint256 collateral) external;
}