//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TigerAtomicSwap is Ownable, ReentrancyGuard {

  struct Swap {
    uint256 openValue;
    address openTrader;
    address openContractAddress;
    uint256 closeValue;
    address closeTrader;
    address closeContractAddress;
  }


  mapping (bytes32 => Swap) private swaps;
  mapping (address => bool) public whitelistedTokens;

  event Open(bytes32 _swapID, address _closeTrader);
  event Expire(bytes32 _swapID);
  event Close(bytes32 _swapID);
  
  function addWhitelistedToken(address _token) onlyOwner public {
      whitelistedTokens[_token] = true;
  }

  function removeWhitelistedToken(address _token) onlyOwner public {
      delete whitelistedTokens[_token];
  }

  function open(bytes32 _swapID, uint256 _openValue, address _openContractAddress, uint256 _closeValue, address _closeTrader, address _closeContractAddress) public nonReentrant {
    require(whitelistedTokens[_openContractAddress] && whitelistedTokens[_closeContractAddress], "ERC20 tokens not allowed");
    
    Swap memory swap = swaps[_swapID];
    require(swap.openTrader == address(0x0), "Swap already exists");

    // Transfer value from the opening trader to this contract.
    IERC20 openERC20Contract = IERC20(_openContractAddress);
    require(_openValue <= openERC20Contract.allowance(msg.sender, address(this)), "Not enough allowance");
    require(openERC20Contract.transferFrom(msg.sender, address(this), _openValue), "Transfered failed");

    // Store the details of the swap.
    swap = Swap({
      openValue: _openValue,
      openTrader: msg.sender,
      openContractAddress: _openContractAddress,
      closeValue: _closeValue,
      closeTrader: _closeTrader,
      closeContractAddress: _closeContractAddress
    });
    swaps[_swapID] = swap;
    

    emit Open(_swapID, _closeTrader);
  }

  function close(bytes32 _swapID) public nonReentrant {
   
    // Close the swap.
    Swap memory swap = swaps[_swapID];
    require(swap.closeTrader == msg.sender, "Only closing trader can close it");
    

    // Transfer the closing funds from the closing trader to the opening trader.
    IERC20 closeERC20Contract = IERC20(swap.closeContractAddress);
    require(swap.closeValue <= closeERC20Contract.allowance(swap.closeTrader, address(this)), "Not enough allowance");
    require(closeERC20Contract.transferFrom(swap.closeTrader, swap.openTrader, swap.closeValue), "Transfer failed");

    // Transfer the opening funds from this contract to the closing trader.
    IERC20 openERC20Contract = IERC20(swap.openContractAddress);
    require(openERC20Contract.transfer(swap.closeTrader, swap.openValue),  "Transfered failed");

    delete swaps[_swapID];

    emit Close(_swapID);
  }

  function expire(bytes32 _swapID) public nonReentrant {
    // Expire the swap.
    Swap memory swap = swaps[_swapID];
    require(swap.openTrader == msg.sender, "Only opening trader can expire it");
    

    // Transfer opening value from this contract back to the opening trader.
    IERC20 openERC20Contract = IERC20(swap.openContractAddress);
    require(openERC20Contract.transfer(swap.openTrader, swap.openValue), "Transfered failed");

    delete swaps[_swapID];

    emit Expire(_swapID);
  }

  function check(bytes32 _swapID) public view returns (uint256 openValue, address openContractAddress, uint256 closeValue, address closeTrader, address closeContractAddress) {
    Swap memory swap = swaps[_swapID];
    return (swap.openValue, swap.openContractAddress, swap.closeValue, swap.closeTrader, swap.closeContractAddress);
  }
}