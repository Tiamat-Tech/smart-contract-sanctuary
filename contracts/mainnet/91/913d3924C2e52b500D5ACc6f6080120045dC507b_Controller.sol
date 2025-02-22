// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.1;
pragma experimental ABIEncoderV2;

import "./interfaces/IController.sol";

contract Controller is IController {
    // Governance
    address public override dao;
    address public override guardian;
    address public override feesOwner;

    // EPools
    bool public override pausedIssuance;

    event SetDao(address dao);
    event SetGuardian(address guardian);
    event SetFeesOwner(address feesOwner);
    event SetPausedIssuance(bool pausedIssuance);

    modifier onlyDao {
        require(msg.sender == dao, "Controller: not dao");
        _;
    }

    modifier onlyDaoOrGuardian {
        require(msg.sender == dao || msg.sender == guardian, "Controller: not dao or guardian");
        _;
    }

    constructor() {
        dao = msg.sender;
        guardian = msg.sender;
    }

    function isDaoOrGuardian(address sender) external view override returns (bool) {
        return (sender == dao || sender == guardian);
    }

    function setDao(address _dao) public override onlyDao returns (bool) {
        dao = _dao;
        emit SetDao(_dao);
        return true;
    }

    function setGuardian(address _guardian) public override onlyDao returns (bool) {
        guardian = _guardian;
        emit SetGuardian(_guardian);
        return true;
    }

    function setFeesOwner(address _feesOwner) public override onlyDao returns (bool) {
        feesOwner = _feesOwner;
        emit SetFeesOwner(_feesOwner);
        return true;
    }

    function setPausedIssuance(bool _pausedIssuance) public override onlyDaoOrGuardian returns (bool) {
        pausedIssuance = _pausedIssuance;
        emit SetPausedIssuance(_pausedIssuance);
        return true;
    }
}