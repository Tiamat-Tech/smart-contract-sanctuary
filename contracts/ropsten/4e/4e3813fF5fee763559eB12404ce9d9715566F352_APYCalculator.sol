pragma solidity ^0.8.0;
// SPDX-License-Identifier: UNLICENSED

// import "./interfaces/IAPYCalculator.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract APYCalculator is AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(address => uint256) amounts;

    constructor() public {
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    modifier onlyAdmin {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not a admin");
        _;
    }

    // returns the value of 3000$ of the given token for rASKO Farm reward calculations
    function valueOf3000(address token) public view returns(uint256 amount){
        return amounts[token];
    }

    function addAdmin(address admin) public onlyAdmin{
        _setupRole(ADMIN_ROLE, admin);
    } 

    function changeValues(address[] memory tokens, uint256[] memory _amounts) public onlyAdmin{
        require(tokens.length == _amounts.length, 'Incorrect parameters');
        for (uint256 i = 0; i < tokens.length; i++) {
            amounts[tokens[i]] = _amounts[i];
        }
    }

}