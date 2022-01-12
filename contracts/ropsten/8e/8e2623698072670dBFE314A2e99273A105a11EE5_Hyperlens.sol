// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Hyperlens is ERC20, Ownable {
    address[] excludedAddresses;

    constructor() ERC20("Hyperlens", "LENS") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }

    function excludeAddressesFromSupply(address[] memory addressesToExclude) public onlyOwner returns (bool) {
        for (uint256 i = 0; i < addressesToExclude.length; i++) {
            excludedAddresses[excludedAddresses.length + 1] = addressesToExclude[i];
        }
        return true;
    }

    function backAddressIntoSupply(address[] memory addressesToBringBack) public onlyOwner returns (bool) {
        address[] memory newExcludedAddresses;
        uint256 index = 0;

        for (uint256 i = 0; i < excludedAddresses.length; i++) {
            bool foundToBringBack = false;
            for (uint256 j = 0; j < addressesToBringBack.length; j++) {
                if (addressesToBringBack[j] == excludedAddresses[i]) {
                    foundToBringBack = true;
                    break;
                }
            }

            if (!foundToBringBack) {
                newExcludedAddresses[index] = excludedAddresses[i];
                index += 1;
            }
        }

        excludedAddresses = newExcludedAddresses;

        return true;
    }

    function totalSupply() public view virtual override returns (uint256) {
        uint256 excludedSupply = 0;
        for (uint256 i = 0; i < excludedAddresses.length; i++) {
            excludedSupply += balanceOf(excludedAddresses[i]);
        }
        return super.totalSupply() - excludedSupply;
    }

    function maxTotalSupply() public view virtual returns (uint256) {
        return super.totalSupply();
    }
}