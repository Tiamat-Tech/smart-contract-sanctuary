// ________ ___       ___  ___  ________ ________ 
//|\  _____\\  \     |\  \|\  \|\  _____\\  _____\
//\ \  \__/\ \  \    \ \  \\\  \ \  \__/\ \  \__/ 
// \ \   __\\ \  \    \ \  \\\  \ \   __\\ \   __\
//  \ \  \_| \ \  \____\ \  \\\  \ \  \_| \ \  \_|
//   \ \__\   \ \_______\ \_______\ \__\   \ \__\ 
//    \|__|    \|_______|\|_______|\|__|    \|__| 
                                                
                                                
                                                
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./Ownable.sol";

contract Snail is ERC20, Ownable {
    address public boneDuckAddress;
    address public stakingAddress;
    
    mapping(address => bool) public allowedAddresses;

    constructor() ERC20("Snail", "SNL") {}
    
    function setBoneDucksAddress(address boneDucksAddr) external onlyOwner {
        boneDuckAddress = boneDucksAddr;
    }
    
    function setStakingAddress(address stakingAddr) external onlyOwner {
        stakingAddress = stakingAddr;
    }
    
    function burn(address user, uint256 amount) external {
        require(msg.sender == stakingAddress || msg.sender == boneDuckAddress, "Address not authorized");
        _burn(user, amount);
    }
    
    function mint(address to, uint256 value) external {
        require(msg.sender == stakingAddress || msg.sender == boneDuckAddress, "Address not authorized");
        _mint(to, value);
    }
}