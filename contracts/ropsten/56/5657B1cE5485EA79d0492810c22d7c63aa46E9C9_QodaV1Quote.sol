//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract ErrorCode {

  enum Error {
              NO_ERROR,
              UNAUTHORIZED,
              SIGNATURE_MISMATCH,
              INVALID_PRINCIPAL,
              INVALID_ENDBLOCK,
              INVALID_SIDE,
              INVALID_NONCE,
              INVALID_QUOTE_EXPIRY_BLOCK,
              TOKEN_INSUFFICIENT_BALANCE,
              TOKEN_INSUFFICIENT_ALLOWANCE,
              MAX_RATE_PER_BLOCK_EXCEEDED,
              QUOTE_EXPIRED,
              LOAN_CONTRACT_NOT_FOUND
  }

  /// @notice Emitted when a failure occurs
  event Failure(uint error);


  /// @notice Emits a failure and returns the error code. WARNING: This function 
  /// returns failure without reverting causing non-atomic transactions. Be sure
  /// you are using the checks-effects-interaction pattern properly with this.
  /// @param err Error code as enum
  /// @return uint Error code cast as uint
  function fail(Error err) internal returns (uint){
    emit Failure(uint(err));
    return uint(err);
  }
  
  /// @notice Emits a failure and returns the error code. WARNING: This function 
  /// returns failure without reverting causing non-atomic transactions. Be sure
  /// you are using the checks-effects-interaction pattern properly with this.
  /// @param err Error code as enum
  /// @return uint Error code cast as uint
  function fail(uint err) internal returns (uint) {
    emit Failure(err);
    return err;
  }
  
}