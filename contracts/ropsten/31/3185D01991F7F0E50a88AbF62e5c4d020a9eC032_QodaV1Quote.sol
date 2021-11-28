// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./libraries/SigVerify.sol";
import "./interfaces/token/IERC20.sol";

contract QodaV1Quote {

  event LenderQuote(
                    address addressLoanToken,
                    address addressLender,
                    uint256 quoteExpiryBlock, //if 0, then quote never expires
                    uint256 endBlock,
                    uint256 notional,
                    uint256 fixedRatePerBlock,
                    uint256 nonce,
                    bytes signature                   
                    );
  
  event BorrowerQuote(
                      address addressLoanToken,
                      address addressBorrower,
                      address addressCollateralToken,
                      uint256 quoteExpiryBlock, //if 0, then quote never expires
                      uint256 endBlock,
                      uint256 notional,
                      uint256 fixedRatePerBlock,
                      uint256 initCollateral,
                      uint256 nonce,
                      bytes signature
                      );

  // When creating a lender quote, addressCollateralToken/initCollateral doesn't
  // need to be specified since the lender does not have to put up any collateral
  function createLenderQuote(
                             address addressLoanToken,
                             address addressLender,
                             uint256 quoteExpiryBlock,
                             uint256 endBlock,
                             uint256 notional,
                             uint256 fixedRatePerBlock,
                             uint256 nonce,
                             bytes memory signature
                             ) public {
    bool isQuoteValid = SigVerify.checkLenderSignature(
                                              addressLoanToken,
                                              addressLender,
                                              quoteExpiryBlock,
                                              endBlock,
                                              notional,
                                              fixedRatePerBlock,
                                              nonce,
                                              signature
                                              );
    require(notional > 0, "notional too small");
    require(isQuoteValid, "signature doesn't match");
    require(checkBalance(addressLender, addressLoanToken, notional), "lender balance too low");
    //require(checkApproval(addressLender, addressLoanToken, notional), "lender must approve contract spend");

    emit LenderQuote(
                     addressLoanToken,
                     addressLender,
                     quoteExpiryBlock,
                     endBlock,
                     notional,
                     fixedRatePerBlock,
                     nonce,
                     signature
                     );
  }

  // INTERNAL FUNCTIONS  
  function checkBalance(
                        address userAddress,
                        address tokenAddress,
                        uint256 amount
                        ) internal view returns(bool){
    if(IERC20(tokenAddress).balanceOf(userAddress) >= amount) {
      return true;
    }
    return false;
  }
  
  function checkApproval(
                         address userAddress,
                         address tokenAddress,
                         uint256 amount
                         ) internal view returns(bool) {
    if(IERC20(tokenAddress).allowance(userAddress, address(this)) > amount){
      return true;
    }
    return false;
  }
}