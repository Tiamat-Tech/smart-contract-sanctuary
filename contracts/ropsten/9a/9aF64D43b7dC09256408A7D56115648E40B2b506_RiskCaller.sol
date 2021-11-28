pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: GPL-3.0-or-later

import "./RiskOracleInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RiskCaller is Ownable {
    RiskOracleInterface private riskOracleInstance;
    address private oracleAddress;
    event NewOracleAddressEvent(address oracleAddress);

    mapping(uint256 => bool) requests;
    event ReceivedNewRequestIdEvent(uint256 id);

    mapping(address => uint256) public tokenVolatilities;
    event VolatilityUpdatedEvent(address token, uint256 volatility);

    constructor() {}

    function setOracleInstanceAddress(address _oracleInstanceAddress) public onlyOwner {
        oracleAddress = _oracleInstanceAddress;
        riskOracleInstance = RiskOracleInterface(oracleAddress);
        emit NewOracleAddressEvent(oracleAddress);
    }

    function updateTokenVolatility(address token) public {
        uint256 id = riskOracleInstance.getTokenVolatility(token);
        requests[id] = true;
        emit ReceivedNewRequestIdEvent(id);
    }

    modifier onlyOracle() {
        require(msg.sender == oracleAddress, "Only oracles can call this function");
        _;
    }
    
    function oracleCallback(address _token, uint256 _volatility, uint256 _id) public onlyOracle {
        require(requests[_id], "Request not in my pending list of requests.");
        tokenVolatilities[_token] = _volatility;
        delete requests[_id];
        emit VolatilityUpdatedEvent(_token, _volatility);
    }
}