pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: GPL-3.0-or-later

import "./RiskCallerInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract RiskOracle is Ownable {
    uint private randNonce = 0;
    uint private modulus = 1000;
    mapping(uint256 => bool) pendingRequests;

    event GetLatestTokenVolatility(address callerAddress, uint id, address token);
    event SetLatestTokenVolatility(address token, uint256 volatility, address callerAddress);

    constructor() {}

    function getTokenVolatility(address token) public returns (uint256) {
        randNonce++;
        uint id = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, token, randNonce))) % modulus;
        pendingRequests[id] = true;
        emit GetLatestTokenVolatility(msg.sender, id, token);
        return id;
    }

    function setTokenVolatility(address _token, uint256 _volatility, address _callerAddress, uint256 _id) public onlyOwner {
        require(pendingRequests[_id], "Request not pending from Oracle.");
        delete pendingRequests[_id];
        RiskCallerInterface riskCallerInstance;
        riskCallerInstance = RiskCallerInterface(_callerAddress);
        riskCallerInstance.oracleCallback(_token, _volatility, _id);
        emit SetLatestTokenVolatility(_token, _volatility, _callerAddress);
    }
}