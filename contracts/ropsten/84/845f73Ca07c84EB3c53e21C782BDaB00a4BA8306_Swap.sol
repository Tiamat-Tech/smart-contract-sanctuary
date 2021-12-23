//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
    @title Contract for swapping `oldToken` to `newToken`

    @dev Requirements: 

    - contract should hold the `newTokens` to be distributed
 */
contract Swap is Ownable, Pausable {
    IERC20 public oldToken;
    IERC20 public newToken;

    // this address is used for superficial burning of tokens, we'll transfer oldTokens here
    address public constant zeroDead = 0x000000000000000000000000000000000000dEaD;

    constructor(IERC20 _oldToken, IERC20 _newToken) public {
        require(
            _oldToken != _newToken && address(_oldToken) != address(0) && address(_newToken) != address(0),
            "wrong token addresses"
        );
        oldToken = _oldToken;
        newToken = _newToken;
    }

    /// Swap `oldToken` with `newToken`
    /// @notice Approve before call
    function swapTokens(uint256 _amount) external whenNotPaused {
        require(oldToken.transferFrom(msg.sender, zeroDead, _amount), "transferFrom of old tokens failed");
        require(newToken.transfer(msg.sender, _amount), "transfer of new tokens failed");
    }

    /// Withdraw any IERC20 tokens accumulated in this contract
    function withdrawTokens(IERC20 _token) external onlyOwner {
        _token.transfer(owner(), _token.balanceOf(address(this)));
    }

    //
    // IMPLEMENT PAUSABLE FUNCTIONS
    //
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}