// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/docs-v4.x/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/docs-v4.x/contracts/security/ReentrancyGuard.sol";

interface IPayment {
   struct Call {
        address target;
        bytes callData;
    }

    event DistributedTokens(IERC20 _token, address[] _users, uint256[] _amount);
    event DistributedEther(address[] _users, uint256[] _amount);

    function distributeTokens(IERC20 _token, address[] calldata _users, uint256[] calldata _amount) external returns (bool);
    function distributeEther(address[] calldata _users, uint256[] calldata _amount) external payable returns (bool);
    function emergencyDrain() external returns (bool);
}

contract Payment is IPayment, ReentrancyGuard {
   using SafeERC20 for IERC20;

   address payable public owner;

   constructor() {
      owner = payable(msg.sender);
   }
   
   function distributeTokens(IERC20 _token, address[] calldata _users, uint256[] calldata _amount) external nonReentrant override virtual returns (bool) {
      require(_users.length == _amount.length ,"user length or amount length is not equvalent");
      for(uint256 i = 0; i < _users.length; i++){
         _token.safeTransferFrom(msg.sender,_users[i],_amount[i]);
      }
      emit DistributedTokens(_token, _users, _amount);
      return true;
   }

   function distributeEther(address[] calldata  _users, uint256[] calldata _amount) external nonReentrant payable override virtual returns (bool) {
      require(_users.length == _amount.length ,"user length or amount length is not equvalent");
      for(uint256 i = 0; i < _users.length; i++) {
         payable(_users[i]).transfer(_amount[i]);
      }
      emit DistributedEther(_users, _amount);

      return true;
   }

   function emergencyDrain() external override virtual returns (bool) {
      require(msg.sender == owner, "Only Owner");
      require(address(this).balance > 0);
      owner.transfer(address(this).balance);
      return true;
   }
    
   function multicall(Call[] memory calls) public returns (bytes[] memory returnData) {
      returnData = new bytes[](calls.length);
      for(uint256 i = 0; i < calls.length; i++) {
         (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
         require(success);
         returnData[i] = ret;
      }
   }

}