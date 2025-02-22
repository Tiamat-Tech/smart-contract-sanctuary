//                        ROGUE TITANS
//
// MMMMMMXk;.;xXWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMNk:':kNMMMMMM
// MMWXkl;.   .,lkKWMMMMMMMMMMMMMMMMMMMMMMMMMMWXko;.   .;oOXWMM
// 0xc'.         ..:d0NMMMMMMMMMMMMMMMMMMMMN0xc'.         .'cxK
// .                 .,lkXWMMMMMMMMMMMMWXOo;.                 .
//                      .'cx0NMMMMMMWKxc'.                     
//                          .:kNNKOo;.                         
//          ;dc'.         .,cllc'..              ..:o;         
//         .lNWXOo;.   .;clc;.                .,lkXWNl.        
//         .lNMMMMN0dlllc,.               ..:d0NMMMMWl.        
//         .lNMMMMN0d:..               .,cllld0NMMMMNl.        
//         .lNWXkl,.                .;llc;..  .;okXWNl.        
//          ;o:..              .,;cllc,.         .'cd;         
//                          .;oONWNk:.                         
//                      .'cxKWMMMMMMN0xc'.                     
// .                 .;oOXWMMMMMMMMMMMMWXkl,.                 .
// Kxc'.         .'cxKWMMMMMMMMMMMMMMMMMMMMN0d:..         .'cd0
// MMWXOo;.   .;oOXWMMMMMMMMMMMMMMMMMMMMMMMMMMWXkl,.   .,lkXWMM
// MMMMMMNk:':kXMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWXx;.:kXMMMMMM
//                                                                                            
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Fragment is ERC1155, ReentrancyGuard, Ownable {

    event Activate();
    event Deactivate();

    event Approval(address indexed contactAddress, address indexed tokenOwner, uint tokens);

    uint256 constant private fragmentId = 1;
    
    uint256 constant public maxFragments = 50000;
    uint256 public numSmeltedFragments;
        
    address public traceContract = 0x93d57b9ba629c65fA7b4C45EF0CAAc20d4518a4c; // TODO Remove me
    address constant public burnAddress = 0x0000000000000000000000000000000000000000;
    uint256 constant public traceThreshold = 20;
    
    bool public isSaleActive = false;
    
    uint256 constant private _smeltPrice = 0.05 ether;

    constructor() ERC1155("https://j3g6pjir50.execute-api.us-east-1.amazonaws.com/dev/fragment") {}

    // Start the sale, and initalize the addresses. Works only one time
    function initializeSale(address traceContract_) public onlyOwner {
        
        require(!isSaleActive, "First disable the Fragment smelting to re-initialize.");

        isSaleActive = true;
        traceContract = traceContract_;

        emit Activate();
    }

    // Withdraw the balance in the account
    function withdrawBalance() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    // Toggle the ability to smelt a fragment on/off
    function toggleSale() public onlyOwner {
        isSaleActive = !isSaleActive;

        if (isSaleActive == true) {
            emit Activate();
        } else {
            emit Deactivate();
        }
    }
    
    // Mint a Fragment
    function smeltFragment(uint256 numFragmentsRequested) external payable nonReentrant {
        IERC20 traceTokenImpl = IERC20(traceContract);
        uint256 traceBurnAmount = numFragmentsRequested * 20;

        require(isSaleActive, "Smelting Fragments is not active at this time.");
        require(numFragmentsRequested > 0, "You must smelt at least 1 whole Fragment.");
        require((numSmeltedFragments + numFragmentsRequested) <= maxFragments, "Requested count for Fragments exceeds the maximum smeltable Fragments.");
       
        require(msg.value >= (numFragmentsRequested * _smeltPrice), "Invalid amount of Ether sent.");
        
        require(traceTokenImpl.balanceOf(msg.sender) >= (traceBurnAmount), "You do not have enough $TRCE to mint a Fragment.");

        try traceTokenImpl.transferFrom(msg.sender, address(burnAddress), traceBurnAmount) {
        } catch (bytes memory) {
            revert("Failed to burn $TRCe - Please verify you have approved the correct number of tokens. Reverting.");
        }
        
        numSmeltedFragments += numFragmentsRequested;
        _mint(msg.sender, fragmentId, numFragmentsRequested, "");
    }
}