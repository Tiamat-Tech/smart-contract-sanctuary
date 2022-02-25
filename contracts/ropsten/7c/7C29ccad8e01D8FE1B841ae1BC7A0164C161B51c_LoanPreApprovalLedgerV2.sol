// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LoanPreApprovalLedgerV2 is Ownable {
  LoanPreApprovalItem[] public LoanPreApprovals;

  struct LoanPreApprovalItem {
    string loanId;
    uint DebtToIncome;
    uint LoanToValue;
    uint256 FICOCreditScore;
    bool preapproved;
    string message;
  }

  struct LoanPreApprovalRequest {
    string loanId;
    uint DebtToIncome;
    uint LoanToValue;
    uint256 FICOCreditScore;
  }

  function submitApplication(LoanPreApprovalRequest calldata information) onlyOwner public {
    LoanPreApprovalItem memory newItem;
    newItem.loanId = information.loanId;
    newItem.DebtToIncome = information.DebtToIncome;
    newItem.LoanToValue = information.LoanToValue;
    newItem.FICOCreditScore = information.FICOCreditScore;
    if (information.FICOCreditScore <= 680){
      newItem.preapproved = false;
      newItem.message = "FICO credit score is too low, must be above 680.";
    } else if (information.LoanToValue > 97) {
      newItem.preapproved = false;
      newItem.message = "Loan To Value (LTV) proportion is too low, must be below 97%.";
    } else if (information.DebtToIncome > 45) {
      newItem.preapproved = false;
      newItem.message = "Debt To Income (DTI) proportion is too low, must be below 45%.";
    } else {
      newItem.preapproved = true;
      newItem.message = "Loan verified successfully, it is currently Pre-approved!";
    }

    return LoanPreApprovals.push(newItem);
  }

  function listAllItems() public view returns (LoanPreApprovalItem[] memory) {
      return LoanPreApprovals;
  }
}