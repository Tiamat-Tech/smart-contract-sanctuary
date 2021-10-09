// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



contract Recharge is Ownable{

    using SafeMath for uint256;

    mapping (uint256 => bool) internal rechargeValueMap;
    address internal receiveAddress;


    /* Event */
    event RechargeSuccess(address sender, uint256 value);
    event ETHReceived(address sender, uint256 value);


    /* Constructor */
    constructor (address _receiveAddress){
        receiveAddress = _receiveAddress;
    }

    //Fallback function
    fallback() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    //Receive function
    receive() external payable {
        // TODO implementation the receive function
    }


    function setRechargeValue(uint256[] memory _rechargeValues) public onlyOwner{
        for (uint256 i = 0; i < _rechargeValues.length; i++){
            rechargeValueMap[_rechargeValues[i]]=true;
        }
    }

    function delRechargeValue(uint256[] memory _rechargeValues)public onlyOwner{
        for (uint256 i = 0; i < _rechargeValues.length; i++){
            rechargeValueMap[_rechargeValues[i]]=false;
        }
    }


    function _contains(uint256 _rechargeValue) internal view returns (bool){
        return rechargeValueMap[_rechargeValue];
    }


    function recharge() public payable{
        require(_contains(uint256(msg.value)),"the recharging amount must be valida!");
        // uint256 rechargeAmountETH = _rechargeAmount.mul(1 ether);
        // totalRechargeAmount = _rechargeAmount.mul(_rechargeValue);
        payable(receiveAddress).transfer(msg.value);
        emit RechargeSuccess(msg.sender,msg.value);
    }

}