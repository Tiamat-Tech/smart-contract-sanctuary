// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "./interfaces/IContractsRegistry.sol";
import "./interfaces/IClaimingRegistry.sol";
import "./interfaces/IPolicyBook.sol";
import "./interfaces/IPolicyRegistry.sol";

contract ClaimingRegistry is IClaimingRegistry, Initializable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 internal constant ANONYMOUS_VOTING_DURATION_CONTRACT = 120;
    uint256 internal constant ANONYMOUS_VOTING_DURATION_EXCHANGE = 300;
    
    uint256 internal constant EXPOSE_VOTE_DURATION = 120;
    uint256 internal constant PRIVATE_CLAIM_DURATION = 120;
    
    IPolicyRegistry public policyRegistry; 
    address public claimVotingAddress;
            
    mapping (address => EnumerableSet.UintSet) internal _myClaims; // claimer -> claim indexes    

    mapping (address => mapping (address => uint256)) internal _allClaimsToIndex; // book -> claimer -> index
    
    mapping (uint256 => ClaimInfo) internal _allClaimsByIndexInfo; // index -> info
    
    EnumerableSet.UintSet internal _pendingClaimsIndexes;
    EnumerableSet.UintSet internal _allClaimsIndexes;

    uint256 private _claimIndex;

    event ClaimPending(address claimer, address policyBookAddress, uint256 claimIndex);
    event ClaimAccepted(address claimer, address policyBookAddress, uint256 claimIndex);
    event ClaimRejected(address claimer, address policyBookAddress, uint256 claimIndex);    
    event AppealRejected(address claimer, address policyBookAddress, uint256 claimIndex);    

    modifier onlyClaimVoting() {
        require(claimVotingAddress == msg.sender, "ClaimingRegistry: Caller is not a ClaimVoting contract");
        _;
    }

    function _isClaimAwaitingCalculation(uint256 index) internal view returns (bool) {
        require (claimExists(index), "ClaimingRegistry: This claim doesn't exist");

        return (_allClaimsByIndexInfo[index].status == ClaimStatus.PENDING && 
            _allClaimsByIndexInfo[index].dateSubmitted.add(votingDuration(index)) <= block.timestamp);
    }

    function __ClaimingRegistry_init(IContractsRegistry _contractsRegistry) external initializer {   
        _claimIndex = 1;

        policyRegistry = IPolicyRegistry(_contractsRegistry.getPolicyRegistryContract());
        claimVotingAddress = _contractsRegistry.getClaimVotingContract();
    }

    function anonymousVotingDuration(uint256 index) public view override returns (uint256) {
        require (claimExists(index), "ClaimingRegistry: This claim doesn't exist");

        return _allClaimsByIndexInfo[index].contractType == IPolicyBookFabric.ContractType.EXCHANGE ?
            ANONYMOUS_VOTING_DURATION_EXCHANGE : ANONYMOUS_VOTING_DURATION_CONTRACT;
    }
    
    function votingDuration(uint256 index) public view override returns (uint256) {
        return anonymousVotingDuration(index).add(EXPOSE_VOTE_DURATION);
    }
    
    function anyoneCanCalculateClaimResultAfter(uint256 index) public view override returns (uint256) {
        return votingDuration(index).add(PRIVATE_CLAIM_DURATION);
    }

    function submitClaim(
        address claimer, 
        address policyBookAddress,          
        bool appeal
    )
        external
        override 
        onlyClaimVoting
        returns (uint256 _newClaimIndex) 
    {
        uint256 index = _allClaimsToIndex[policyBookAddress][claimer];
        bool contains = _myClaims[claimer].contains(index);

        uint256 startTime = policyRegistry.policyStartTime(claimer, policyBookAddress);
        ClaimStatus status = _allClaimsByIndexInfo[index].status;
        
        // (3) when a user of old policy has an approved or rejected claim and he claims again from a new policy
        require ((!appeal && !contains) ||
            (appeal && contains && status == ClaimStatus.REJECTED_CAN_APPEAL) || 
            (!appeal && contains && startTime > _allClaimsByIndexInfo[index].dateSubmitted && 
                status != ClaimStatus.PENDING), 
            "ClaimingRegistry: The claimer can't submit this claim");
        
        if (appeal) {
            _allClaimsByIndexInfo[index].status = ClaimStatus.REJECTED;
        }

        (uint256 claimAmount, , , , ) = IPolicyBook(policyBookAddress).userStats(claimer);

        _myClaims[claimer].add(_claimIndex);        

        _allClaimsToIndex[policyBookAddress][claimer] = _claimIndex;

        _allClaimsByIndexInfo[_claimIndex] = ClaimInfo(
            _claimIndex,
            claimer,
            policyBookAddress,
            IPolicyBook(policyBookAddress).contractType(),     
            appeal,
            block.timestamp,
            ClaimStatus.PENDING,
            claimAmount
        );
        
        _pendingClaimsIndexes.add(_claimIndex);
        _allClaimsIndexes.add(_claimIndex);                

        _newClaimIndex = _claimIndex++;

        emit ClaimPending(claimer, policyBookAddress, _newClaimIndex);
    }

    function claimExists(uint256 index) public view override returns (bool) {
        return _allClaimsIndexes.contains(index);
    }    

    function claimSubmittedTime(uint256 index) external view override returns (uint256) {
        return _allClaimsByIndexInfo[index].dateSubmitted;
    }

    function isClaimAnonymouslyVotable(uint256 index) external view override returns (bool) {
        return (_pendingClaimsIndexes.contains(index) && 
            _allClaimsByIndexInfo[index].dateSubmitted.add(anonymousVotingDuration(index)) > block.timestamp);
    }
    
    function isClaimExposablyVotable(uint256 index) external view override returns (bool) {
        return (_pendingClaimsIndexes.contains(index) && 
            _allClaimsByIndexInfo[index].dateSubmitted.add(votingDuration(index)) > block.timestamp && 
            _allClaimsByIndexInfo[index].dateSubmitted.add(anonymousVotingDuration(index)) < block.timestamp);
    }

    function canClaimBeCalculatedByAnyone(uint256 index) external view override returns (bool) {
        return _isClaimAwaitingCalculation(index) && _allClaimsByIndexInfo[index].dateSubmitted
            .add(anyoneCanCalculateClaimResultAfter(index)) <= block.timestamp;
    }

    function isClaimPending(uint256 index) external view override returns (bool) {
        return _pendingClaimsIndexes.contains(index);
    }

    function countPolicyClaimerClaims(address claimer) external view override returns (uint256) {
        return _myClaims[claimer].length();
    }

    function countPendingClaims() external view override returns (uint256) {
        return _pendingClaimsIndexes.length();
    }

    function countClaims() external view override returns (uint256) {
        return _allClaimsIndexes.length();
    }    

    function claimOfOwnerIndexAt(address claimer, uint256 orderIndex) external view override returns (uint256) {
        return _myClaims[claimer].at(orderIndex);
    }

    function pendingClaimIndexAt(uint256 orderIndex) external view override returns (uint256) {
        return _pendingClaimsIndexes.at(orderIndex);
    }

    function claimIndexAt(uint256 orderIndex) external view override returns (uint256) {
        return _allClaimsIndexes.at(orderIndex);
    }

    function claimIndex(address claimer, address policyBookAddress) external view override returns (uint256) {
        return _allClaimsToIndex[policyBookAddress][claimer];
    }

    function isClaimAppeal(uint256 index) external view override returns (bool) {
        return _allClaimsByIndexInfo[index].appeal;
    }

    function policyStatus(address claimer, address policyBookAddress) external view override returns (ClaimStatus) {
        if (policyRegistry.isPolicyActive(claimer, policyBookAddress)) {
            uint256 index = _allClaimsToIndex[policyBookAddress][claimer];
        
            if (_myClaims[claimer].contains(index)) {
                return claimStatus(index);
            }

            return ClaimStatus.CAN_CLAIM;
        } 

        return ClaimStatus.UNCLAIMABLE;
    }

    function claimStatus(uint256 index) public view override returns (ClaimStatus) {
        return
            (_isClaimAwaitingCalculation(index) ?
            ClaimStatus.AWAITING_CALCULATION :
            _allClaimsByIndexInfo[index].status);
    }

    function claimOwner(uint256 index) external view override returns (address) {
        return _allClaimsByIndexInfo[index].claimer;
    }

    function claimInfo(uint256 index)
        external
        view
        override
        returns (ClaimInfo memory _claimInfo)
    {
        require (claimExists(index), "ClaimingRegistry: This claim doesn't exist");

        _claimInfo = ClaimInfo(
            index,
            _allClaimsByIndexInfo[index].claimer,
            _allClaimsByIndexInfo[index].policyBookAddress,
            _allClaimsByIndexInfo[index].contractType,
            _allClaimsByIndexInfo[index].appeal,
            _allClaimsByIndexInfo[index].dateSubmitted,
            claimStatus(index),
            _allClaimsByIndexInfo[index].claimAmount
        );
    }

    function _modifyClaim(uint256 index, bool accept) internal {
        require (_isClaimAwaitingCalculation(index), "ClaimingRegistry: The claim is not awaiting");

        address claimer = _allClaimsByIndexInfo[index].claimer;
        address policyBookAddress = _allClaimsByIndexInfo[index].policyBookAddress;
        
        if (accept) {
            _allClaimsByIndexInfo[index].status = ClaimStatus.ACCEPTED;            

            emit ClaimAccepted(claimer, policyBookAddress, index);
        } else if (!_allClaimsByIndexInfo[index].appeal) {
            _allClaimsByIndexInfo[index].status = ClaimStatus.REJECTED_CAN_APPEAL;

            emit ClaimRejected(claimer, policyBookAddress, index);
        } else {
            _allClaimsByIndexInfo[index].status = ClaimStatus.REJECTED;
            delete _allClaimsToIndex[policyBookAddress][claimer];

            emit AppealRejected(claimer, policyBookAddress, index);
        }

        _pendingClaimsIndexes.remove(index);
    }

    function acceptClaim(uint256 index) external override onlyClaimVoting {
        _modifyClaim(index, true);
    }

    function rejectClaim(uint256 index) external override onlyClaimVoting {
        _modifyClaim(index, false);
    }
}