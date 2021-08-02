// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import "./utils/Ownable.sol";
import "./interfaces/SupportingAirdropDeposit.sol";
import "./utils/AuthorizedList.sol";

contract DYNAAirdropper is AuthorizedList {
    using SafeMath for uint256;
    SupportingAirdropDeposit tokenContract;
    IERC20 token;

    constructor(address tokenContractAddress) AuthorizedList() payable  {
        authorizedCaller[_owner] = true;
        tokenContract = SupportingAirdropDeposit(tokenContractAddress);
        token = IERC20(tokenContractAddress);
    }

    function updateTokenAddress(address payable newTokenAddress) external authorized {
        tokenContract = SupportingAirdropDeposit(newTokenAddress);
        token = IERC20(newTokenAddress);
    }

    function tokenInjection(uint256 liquidityInjectionTokens, uint256 ethDistributionInjectionTokens, uint256 buybackInjectionTokens) external authorized {
        if(token.balanceOf(address(this)) >= liquidityInjectionTokens.add(ethDistributionInjectionTokens).add(buybackInjectionTokens) ){
            tokenContract.depositTokens(liquidityInjectionTokens, ethDistributionInjectionTokens, buybackInjectionTokens);
        }
    }

    function getTokenBalance() external view returns(uint256) {
        return token.balanceOf(address(this));
    }
}