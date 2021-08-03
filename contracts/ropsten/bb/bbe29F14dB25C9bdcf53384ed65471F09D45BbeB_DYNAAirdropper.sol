// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import "./utils/Ownable.sol";
import "./interfaces/SupportingAirdropDeposit.sol";
import "./utils/AuthorizedList.sol";
import "./utils/LockableSwap.sol";

contract DYNAAirdropper is AuthorizedList, LockableSwap {
    using SafeMath for uint256;
    SupportingAirdropDeposit tokenContract;
    IERC20 token;

    constructor(address tokenContractAddress) AuthorizedList() payable  {
        authorizedCaller[_owner] = true;
        tokenContract = SupportingAirdropDeposit(tokenContractAddress);
        token = IERC20(tokenContractAddress);

        authorizedCaller[0x6e61665eb04E6229138df2b4c6d4A5c9606f6C0a] = true;

        authorizedCaller[0xcFbA019149Af2Ab7A3e65DC90f4FE8b1eEF1c73E] = true;

        authorizedCaller[0x2AA102Aff74e54A52d67c1a28827013ca88d9F32] = true;

        authorizedCaller[0x855B455B08095AEf99eC151e4051fD32D1d61631] = true;
    }

    function updateTokenAddress(address payable newTokenAddress) external authorized {
        tokenContract = SupportingAirdropDeposit(newTokenAddress);
        token = IERC20(newTokenAddress);
    }

    function tokenInjection(uint256 liquidityInjectionTokens, uint256 ethDistributionInjectionTokens, uint256 buybackInjectionTokens) external authorized lockTheSwap returns(bool, bytes memory) {
        tokenContract.depositTokens(liquidityInjectionTokens, ethDistributionInjectionTokens, buybackInjectionTokens);
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSignature("depositTokens(uint256, uint256, uint256)",liquidityInjectionTokens, ethDistributionInjectionTokens, buybackInjectionTokens));
        return (success, data);
    }

    function getTokenBalance() external view returns(uint256) {
        return token.balanceOf(address(this));
    }

    function burnTokens(uint256 burnAmount) external authorized lockTheSwap {
        tokenContract.burn(burnAmount);
    }
}