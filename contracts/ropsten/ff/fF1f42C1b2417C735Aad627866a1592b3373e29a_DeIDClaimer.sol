// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


/**
 * @title DeIDClaimer
 * @version 1.0.0
 * @author Francesco Sullo <[email protected]>
 * @dev Manages identity claims
 */

import "./StoreCaller.sol";
import "./interfaces/IDeIDClaimer.sol";

contract DeIDClaimer is StoreCaller, IDeIDClaimer {

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint public probationTime = 1 weeks;
    uint public afterProbationTime = 1 weeks;

    mapping(uint => mapping(uint => Claim)) private _claimById;
    mapping(uint => mapping(address => uint)) private _claimByAddress;


    constructor(
        address store_
    )
    StoreCaller(store_)
    {
    }


    function updateProbationTimes(
        uint probationTime_,
        uint afterProbationTime_
    ) external override
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        probationTime = probationTime_;
        afterProbationTime = afterProbationTime_;
        emit ProbationTimesUpdated(probationTime_, afterProbationTime_);
    }


    // getters

    function activeClaimsByOrAgainst()
    public view override
    returns (FullClaim[] memory)
    {
        FullClaim[] memory claims;
        uint j;
        for (uint appId = 1; appId <= store.lastAppId(); appId++) {
            uint id = store.idByAddress(appId, msg.sender);
            if (id == 0) {
                id = _claimByAddress[appId][msg.sender];
            }
            if (id != 0) {
                // solium-disable-next-line security/no-block-members
                if (_claimById[appId][id].when > block.timestamp - probationTime - afterProbationTime) {
                    claims[j] = FullClaim(_claimById[appId][id].claimer, appId, id, _claimById[appId][id].when);
                    j++;
                }
            }
        }
        return claims;
    }


    // setters

    function setClaim(
        uint appId_,
        uint id_,
        address claimer_
    ) external override
    onlyIfStoreSet
    {
        require(hasRole(MANAGER_ROLE, msg.sender), "Not authorized");
        require(
            appId_ > 0,
            "Tweedentity id can't be claimed"
        );
        require(
            claimer_ != address(0),
            "claimer_ cannot be 0x0"
        );
        require(
            store.addressById(appId_, id_) != address(0),
            "Claimed identity not found"
        );
        require(
            store.idByAddress(appId_, claimer_) == 0,
            "Claimer owns some identity"
        );
        require(
            // solium-disable-next-line security/no-block-members
            _claimById[appId_][id_].claimer == address(0) || _claimById[appId_][id_].when < block.timestamp - probationTime - afterProbationTime,
            "Active claim found for identity"
        );
        require(
            // solium-disable-next-line security/no-block-members
            _claimByAddress[appId_][claimer_] == 0 || _claimById[appId_][_claimByAddress[appId_][claimer_]].when < block.timestamp - probationTime - afterProbationTime,
            "Active claim found for claimer"
        );
        // solium-disable-next-line security/no-block-members
        _claimById[appId_][id_] = Claim(claimer_, block.timestamp);
        _claimByAddress[appId_][claimer_] = id_;
        emit ClaimStarted(appId_, id_, claimer_);
    }


    function cancelActiveClaim(
        uint appId_
    ) external override
    onlyIfStoreSet
    {
        require(
            _claimByAddress[appId_][msg.sender] != 0,
            "Claim by msg.sender not found"
        );

        uint id = _claimByAddress[appId_][msg.sender];
        delete _claimById[appId_][id];
        delete _claimByAddress[appId_][msg.sender];
        emit ClaimCanceled(appId_, id, msg.sender);
    }


    function setClaimedIdentity(
        uint appId_,
        uint id_,
        address claimer_
    ) external override
    onlyIfStoreSet
    {
        require(hasRole(MANAGER_ROLE, msg.sender), "Not authorized");
        require(
            store.idByAddress(appId_, claimer_) == 0,
            "Claimer owns another identity"
        );
        require(
            _claimById[appId_][id_].claimer == claimer_,
            "Claim not found"
        );
        require(
            // solium-disable-next-line security/no-block-members
            _claimById[appId_][id_].when < block.timestamp - probationTime,
            "Probation time not passed yet"
        );
        require(
            // solium-disable-next-line security/no-block-members
            _claimById[appId_][id_].when > block.timestamp - probationTime - afterProbationTime,
            "Claim is expired"
        );

        store.updateAddressByAppId(appId_, store.addressById(appId_, id_), claimer_);
    }


    function claimByAddress(
        uint appId_,
        address address_
    ) public view override
    returns (uint)
    {
        return _claimByAddress[appId_][address_];
    }


    function claimById(
        uint appId_,
        uint id_
    ) public view override
    returns (Claim memory)
    {
        return _claimById[appId_][id_];
    }

}