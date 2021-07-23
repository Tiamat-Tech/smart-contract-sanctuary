pragma solidity ^0.6.6;

interface IVault {
    function receiveAEthFrom(address from, uint vol) external;
}