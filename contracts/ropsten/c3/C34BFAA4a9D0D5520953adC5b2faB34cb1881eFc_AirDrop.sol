// contracts/MyNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
//import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


//import "hardhat/console.sol";

contract AirDrop is AccessControlEnumerable, Ownable  {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    ///bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant WHITELISTER_ROLE = keccak256("WHITELISTER_ROLE");

    mapping(address => uint256) private whiteList;

    address public tokenAddress ;


    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
        //owner = msg.sender;

        //Note that unlike grantRole, this function doesn’t perform any checks on the calling account.
        //the owner has admin role
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function addToWhiteList(address _addres, uint256 _amount) public onlyRole(WHITELISTER_ROLE) {
        whiteList[_addres] = whiteList[_addres] + _amount;
    }

    function substractFromWhiteList(address _addres, uint256 _amount) public onlyRole(WHITELISTER_ROLE) {
        require(whiteList[_addres] >= _amount,"The amount is to high");
        whiteList[_addres] = whiteList[_addres] - _amount;
    }    

    function isWhiteListed(address _address) public view onlyRole(WHITELISTER_ROLE) returns(bool b){
        return whiteList[_address]!=0;
    }

    function getWhiteListedClaimableBalance(address _address) public view onlyRole(WHITELISTER_ROLE) returns(uint256 amt){
        return whiteList[_address];
    }

    function getMyClaimableBalance() external view returns(uint256 amt) {
        return whiteList[msg.sender];
    }


    //Users on the whitelist call this function to claim their rewards
    function claimTokens(uint256 _amount)  external {

        require(whiteList[msg.sender]!=0,"User not on the list");
        require(whiteList[msg.sender]>=_amount,"Not enough on user's balance");

/*
        this is not needed. The transaccion will not go through when
        the allowance is not enough

        //Returns the remaining number of tokens that spender will be 
        //allowed to spend on behalf of owner through transferFrom. This is zero by default.
        uint256 amtLeft = IERC20(tokenAddress).allowance( owner, address(this) );
        require(amtLeft>=_amount,"Not enough allowance");
*/

        //transfers the amount
        IERC20(tokenAddress).transferFrom(owner(), msg.sender, _amount);

        //Substracts the amount from user in whiteList
        whiteList[msg.sender] = whiteList[msg.sender] - _amount;
    }

}