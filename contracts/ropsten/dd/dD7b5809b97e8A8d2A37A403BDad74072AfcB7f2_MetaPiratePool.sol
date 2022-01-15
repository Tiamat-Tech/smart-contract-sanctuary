// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IMetaPirateToken.sol";
import "./IMetaPiratePool.sol";

contract MetaPiratePool is AccessControlEnumerable , IMetaPiratePool {

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint8 public atLeastSignerCount;
    uint8 public atLeastAdminCount;
    address public tokenAddress = address(0);
    EnumerableSet.Bytes32Set private pendingSignerLevelRequests;
    EnumerableSet.Bytes32Set private pendingAdminLevelRequests;
    mapping(bytes32 => SendRequest ) private transferRequests; 
    mapping(bytes32 => AuditRecord ) private auditTransferRequests;

    constructor(uint8 atLeastSignerCount_, uint8 atLeastAdminCount_)  {
       _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());       
       atLeastSignerCount = atLeastSignerCount_;
       atLeastAdminCount = atLeastAdminCount_;      
    }


    function bindingToken(address tokenAddress_) public returns(bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE,_msgSender()),"MetaPiratePool: must have DEFAULT_ADMIN_ROLE role to bindingToken");
        tokenAddress = tokenAddress_;
        emit BindingToken(tokenAddress_);
        return true;
    }

    function getTransferRequest(bytes32 requestID_) public view returns(SendRequest memory request,AuditRecord memory audit) {
        return (transferRequests[requestID_],auditTransferRequests[requestID_]);
    }

    function listPendingTransaction(AuditLevel level) public view returns(bytes32[] memory) {
        if(level == AuditLevel.Admin) {            
            return pendingAdminLevelRequests.values();
        }        
        return pendingSignerLevelRequests.values();
    }

    function transferWithLock(bytes32 requestID_,address to_,uint256 amount_,uint256 releaseTime_) public returns(bool) {
        
        require(hasRole(SIGNER_ROLE,_msgSender()),"MetaPiratePool: must have SIGNER_ROLE role to transferWithLock");
        require(to_ != address(0), "MetaPiratePool: transfer to the zero address");
        require(transferRequests[requestID_].requestID == bytes32(0) , "MetaPiratePool: the request already exists");
        require(auditTransferRequests[requestID_].requestID == bytes32(0) , "MetaPiratePool: the audit already exists");
        
        transferRequests[requestID_] = SendRequest(requestID_,to_,amount_,releaseTime_);
        
        auditTransferRequests[requestID_].requestID = requestID_;
        auditTransferRequests[requestID_].auditors = new address[](atLeastSignerCount+atLeastAdminCount);
        auditTransferRequests[requestID_].auditors[0] = _msgSender();
        auditTransferRequests[requestID_].statuses = new AuditStatus[](atLeastSignerCount+atLeastAdminCount);
        auditTransferRequests[requestID_].statuses[0] = AuditStatus.Approve;
        auditTransferRequests[requestID_].auditedCount = 1;
        
        pendingSignerLevelRequests.add(requestID_);
        
        emit TransferWithLockRequest(to_,requestID_,releaseTime_,amount_);
        emit TransferWithLockAudit(to_,requestID_,releaseTime_,amount_,_msgSender(), AuditLevel.Signer, AuditStatus.Approve);    
        return true;
    }

    function auditTransferForSigner(bytes32 requestID_ , AuditStatus status_) public returns(bool) {
        require(hasRole(SIGNER_ROLE,_msgSender()),"MetaPiratePool: must have SIGNER_ROLE role to auditTransferForSigner");        
        require(!auditTransferRequests[requestID_].isFinished,"MetaPiratePool: the request is finished");
        require(transferRequests[requestID_].requestID == requestID_ , "MetaPiratePool: the request not exists");
        require(pendingSignerLevelRequests.contains(requestID_), "MetaPiratePool: the request does not belong to  not Signer level");
        
        bool isRepeatAudit = false;
        uint8 auditedSignerCount = 0;        
        for(uint i = 0; i < auditTransferRequests[requestID_].auditedCount;i++){
            if(hasRole(SIGNER_ROLE,auditTransferRequests[requestID_].auditors[i])){
                auditedSignerCount++ ; 
            }
            if(auditTransferRequests[requestID_].auditors[i] == _msgSender()){
                isRepeatAudit = true;
                break;
            }            
        }
        require(!isRepeatAudit,"MetaPiratePool: request cannot be reviewed repeatedly");

        uint8 nextIndex = auditTransferRequests[requestID_].auditedCount;
        auditTransferRequests[requestID_].auditors[nextIndex] = _msgSender();
        auditTransferRequests[requestID_].statuses[nextIndex] = status_;
        
        auditTransferRequests[requestID_].auditedCount = nextIndex + 1;

        emit TransferWithLockAudit(transferRequests[requestID_].beneficiaryAddress,transferRequests[requestID_].requestID,transferRequests[requestID_].releaseTime,transferRequests[requestID_].amount,_msgSender(),AuditLevel.Signer,status_);

        if(status_ == AuditStatus.Reject) {
            auditTransferRequests[requestID_].isFinished = true;
            pendingSignerLevelRequests.remove(requestID_);    
        }else{
            auditedSignerCount++;
            
            if(auditedSignerCount >= atLeastSignerCount){
                pendingAdminLevelRequests.add(requestID_);
                pendingSignerLevelRequests.remove(requestID_);
            }
        }

        return true;
    }


    function  auditTransferForAdmin(bytes32 requestID_ ,  AuditStatus status_) public returns(bool) {

        require(transferRequests[requestID_].requestID == requestID_ , "MetaPiratePool: the request not exists");
        require(!auditTransferRequests[requestID_].isFinished,"MetaPiratePool: the request is finished");
        require(pendingAdminLevelRequests.contains(requestID_), "MetaPiratePool: the request does not belong to  not Admin level");
        require(hasRole(ADMIN_ROLE,_msgSender()),"MetaPiratePool: must have ADMIN_ROLE role to auditTransfer");     
        
        bool isRepeatAudit = false;
        uint8 auditedSignerCount = 0;
        uint8 auditedAdminCount = 0;
        for(uint i = 0; i < auditTransferRequests[requestID_].auditedCount;i++){
            if(hasRole(SIGNER_ROLE,auditTransferRequests[requestID_].auditors[i])){
                auditedSignerCount++ ; 
            }else if(hasRole(ADMIN_ROLE,auditTransferRequests[requestID_].auditors[i])){
                auditedAdminCount ++ ; 
            }

            if(auditTransferRequests[requestID_].auditors[i] == _msgSender()){
                isRepeatAudit = true;
                break;
            }            
        }
        require(!isRepeatAudit,"MetaPiratePool: request cannot be reviewed repeatedly");
        require(auditedSignerCount >= atLeastSignerCount,"MetaPiratePool: ADMIN_ROLE audit must be completed after SIGNER_ROLE audit");     

        uint8 nextIndex = auditTransferRequests[requestID_].auditedCount;
        auditTransferRequests[requestID_].auditors[nextIndex] = _msgSender();
        auditTransferRequests[requestID_].statuses[nextIndex] = status_;
        
        auditTransferRequests[requestID_].auditedCount = nextIndex + 1;

        emit TransferWithLockAudit(transferRequests[requestID_].beneficiaryAddress,transferRequests[requestID_].requestID,transferRequests[requestID_].releaseTime,transferRequests[requestID_].amount,_msgSender(),AuditLevel.Admin,status_);

        if(status_ == AuditStatus.Reject) {
            auditTransferRequests[requestID_].isFinished = true;
            pendingAdminLevelRequests.remove(requestID_);    
        }else{
            auditedAdminCount++;
            if(auditedSignerCount >= atLeastSignerCount &&  auditedAdminCount >= atLeastAdminCount){
                auditTransferRequests[requestID_].isFinished = true;                                
                require(tokenAddress != address(0),"MetaPiratePool: token is not bound to the address ");

                uint256 existLockAmount = IMetaPirateToken(tokenAddress).tokensLockedAtTime(transferRequests[requestID_].beneficiaryAddress, transferRequests[requestID_].releaseTime);
                if(existLockAmount == 0){
                    bool  lockSuccess = IMetaPirateToken(tokenAddress).lock(transferRequests[requestID_].beneficiaryAddress,transferRequests[requestID_].releaseTime,transferRequests[requestID_].amount);
                    require(lockSuccess,"MetaPiratePool: failed to lock token");
                }else{
                    bool  addLockAmountSuccess =  IMetaPirateToken(tokenAddress).increaseLockAmount(transferRequests[requestID_].beneficiaryAddress,transferRequests[requestID_].releaseTime,transferRequests[requestID_].amount);
                    require(addLockAmountSuccess,"MetaPiratePool: failed to increase locked amount");
                }
            }
        }

        return true;
    }

    
    
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IMetaPiratePool).interfaceId || super.supportsInterface(interfaceId);
    }
}