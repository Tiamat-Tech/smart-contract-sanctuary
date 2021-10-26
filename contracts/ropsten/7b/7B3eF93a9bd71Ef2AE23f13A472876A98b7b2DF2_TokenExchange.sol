// SPDX-License-Identifier: GPL-2.0-or-later





pragma solidity =0.7.6;

import '../libraries/Owned.sol';
import '../libraries/SafeERC20.sol';
import './ERC20Burnable.sol';

contract TokenExchange is Owned {
    using SafeERC20 for IERC20; 

    // bytes4(keccak256(bytes("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)")));
    bytes4 constant _PERMIT_SIGNATURE = 0xd505accf;
    
    // Swap ratio from ASUM to SUM multiplied by 1000
    uint256 public constant SWAP_RATIO = 1000;

    // ASUM token address
    IERC20 public immutable aSum;

    // SUM token address
    IERC20 public immutable sum;
    
    // UNIX time in seconds when the owner will be able to withdraw the remaining SUM tokens
    uint256 public withdrawTimeout;

    /**
     * @dev Emitted when someone swap ASUM for SUM
     */
    event ASumToSum(uint256 aSumAmount, uint256 sumAmount, address indexed grantee);

    /**
     * @dev Emitted when the owner increases the timeout
     */
    event NewWithdrawTimeout(uint256 newWithdrawTimeout);

    /**
     * @dev Emitted when the owner withdraw tokens
     */
    event WithdrawTokens(address tokenAddress, uint256 amount);

    /**
     * @dev This contract will receive SUM tokens, the users will be able to swap their ASUM tokens for SUM tokens
     *      as long as this contract holds enough amount. The swapped ASUM tokens will be burned.
     *      Once the withdrawTimeout is reached, the owner will be able to withdraw the remaining SUM tokens.
     * @param _aSum ASUM token address
     * @param _sum SUM token address
     * @param duration Time in seconds that the owner will not be able to withdraw the SUM tokens
     */
    constructor (
        IERC20 _aSum,
        IERC20 _sum,
        uint256 duration
    ){
        aSum = _aSum;
        sum = _sum;
        withdrawTimeout = block.timestamp + duration;
    }

    /**
     * @notice Method that allows swap ASUM for SUM tokens at the ratio of 1 ASUM --> 1 SUM
     * Users can either use the permit functionality, or approve previously the tokens and send an empty _permitData
     * @param aSumAmount Amount of SUM to swap
     */
    function aSumToSum(uint256 aSumAmount) public {

        aSum.safeTransferFrom(msg.sender, address(this), aSumAmount);

        ERC20Burnable(address(aSum)).burn(aSumAmount);

        // transfer SUM tokens
        uint256 sumAmount = (aSumAmount * SWAP_RATIO) / 1000;
        sum.safeTransfer(msg.sender, sumAmount);

        emit ASumToSum(aSumAmount, sumAmount, msg.sender);
    }

    /**
     * @notice Method that allows the owner to withdraw any token from this contract
     * In order to withdraw SUM tokens the owner must wait until the withdrawTimeout expires
     * @param tokenAddress Token address
     * @param amount Amount of tokens to withdraw
     */
    function withdrawTokens(address tokenAddress, uint256 amount) public onlyOwner {
        if(tokenAddress == address(sum)) {
            require(
                block.timestamp > withdrawTimeout,
                "TokenExchange::withdrawTokens: TIMEOUT_NOT_REACHED"
            );
        }
        
        IERC20(tokenAddress).safeTransfer(owner, amount);

        emit WithdrawTokens(tokenAddress, amount);
    }

    /**
     * @notice Method that allows the owner to increase the withdraw timeout
     * @param newWithdrawTimeout new withdraw timeout
     */
    function setWithdrawTimeout(uint256 newWithdrawTimeout) public onlyOwner {
        require(
            newWithdrawTimeout > withdrawTimeout,
             "TokenExchange::setWithdrawTimeout: NEW_TIMEOUT_MUST_BE_HIGHER"
        );
        
        withdrawTimeout = newWithdrawTimeout; 
        
        emit NewWithdrawTimeout(newWithdrawTimeout);
    }

   
}