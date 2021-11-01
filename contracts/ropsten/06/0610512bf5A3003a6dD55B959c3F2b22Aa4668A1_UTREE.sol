// SPDX-License-Identifier: Apache-2.0 AND MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title UTREE token contract
 *
 * @dev Token contract based on {ERC20} and {Ownable} contracts from OpenZeppelin
 */
contract UTREE is ERC20, Ownable {
    address private _staking;
    address private _voting;

    /**
     * @dev See {ERC20}.
     */
    constructor(uint256 initial) ERC20("UTREE", "UTREE") {
        _mint(_msgSender(), initial);
    }

    /**
     * @dev Burn `amount` of tokens from owner account, see {ERC20-_burn}
     *
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external onlyOwner {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Mint `amount` of tokens to owner account, see {ERC20-_mint}
     *
     * @param amount Amount to mint
     */
    function mint(uint256 amount) external onlyOwner {
        _mint(_msgSender(), amount);
    }

    /**
     * @dev Set `staking` contract address, that could approve token transfers
     *
     * @param staking Staking contract address
     */
    function setStaking(address staking) external onlyOwner {
        require(staking != address(0), "Cannot set zero address");

        _staking = staking;
    }

    /**
     * @dev Set `voting` contract address, that could approve token transfers
     *
     * @param voting Voting contract address
     */
    function setVoting(address voting) external onlyOwner {
        require(voting != address(0), "Cannot set zero address");

        _voting = voting;
    }

    /**
     * @dev Allow only specified addresses to call
     */
    modifier onlyAllowed() {
        require(_msgSender() == _staking || _msgSender() == _voting, "Only specified addresses allowed");
        _;
    }

    /**
     * @dev Approve allowance to transfer tokens `amount` from `owner` to `spender`, see {ERC20-_approve}
     *
     * @param owner Tokens owner from whom it is allowed to transfer tokens
     * @param spender Someone who can transfer tokens
     * @param amount Amount of tokens allowance to transfer
     */
    function approveTransfer(
        address owner,
        address spender,
        uint256 amount
    ) external onlyAllowed {
        _approve(owner, spender, amount);
    }
}