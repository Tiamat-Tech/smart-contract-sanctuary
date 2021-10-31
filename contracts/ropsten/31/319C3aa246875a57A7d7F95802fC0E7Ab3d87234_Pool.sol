// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.9;

import "./strings.sol";
/// @notice DETF pool smart contract
/// @author D-ETF.com
/// @dev The Pool contract keeps all underlaying tokens of DETF token.
/// Contract allowed to do swaps and change the ratio of the underlaying token, after governance contract approval.
contract Pool {
    using Strings for *;
    event Swapped(address srcToken, address destToken, uint256 actSrcAmount, uint256 actDestAmount);
    uint256 public res;
    
    function swap(
        address srcToken,
        uint256 minPrice,
        address destToken
    ) public {
        
        uint256 actualSrcAmount = minPrice + 1;
        uint256 actualDestAmount = minPrice + 1;
        emit Swapped(srcToken, destToken, actualSrcAmount, actualDestAmount);
    }
    
    mapping (address => mapping(address => uint256)) public addresses;
    
    function setAddress(address sender, address recipient, uint256 amount) public {
        addresses[sender][recipient] = amount;
    }
    uint256 public constant MAX_COMMITTEE_MEMBER_COUNT = 11;
    
    function convert(string memory str) public view returns(string[] memory) {
        
        return str.split("|");
    }
}