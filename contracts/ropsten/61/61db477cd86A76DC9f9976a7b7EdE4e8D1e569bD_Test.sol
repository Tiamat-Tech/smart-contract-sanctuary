// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Test is AccessControl {    
    bytes32 public constant VERIFIED_ROLE = keccak256("VERIFIED_ROLE");

    constructor() {
        _setupRole(VERIFIED_ROLE, msg.sender);
        _setRoleAdmin(VERIFIED_ROLE, VERIFIED_ROLE);    // their own admin
    }

    modifier onlyVerified() {
        require(hasRole(VERIFIED_ROLE, msg.sender), "!verified");
        _;
    }

    function getTokenBalance(address _token, address _guy) external view onlyVerified returns (uint) {
        return IERC20(_token).balanceOf(_guy);
    }

    function strToBytes32(string memory _text) external pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(_text);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(_text, 32))
        }
    }
    
    receive() external payable {}
}