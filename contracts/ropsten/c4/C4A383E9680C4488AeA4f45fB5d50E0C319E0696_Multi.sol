// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./IERC20.sol";
import ".//SafeMath.sol";

// // import "./Arrays.sol";
// import "@openzeppelin/contracts/utils/Address.sol";
import "./ERC20.sol";
import "./Ownable.sol";
import "./Context.sol";
import "./SafeERC20.sol";
import "./TransferHelper.sol";


contract Multi is Ownable {
using SafeMath for uint256;
using SafeERC20 for IERC20;


address public airdroptoken;

bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));



function changeToken(address newToken)public onlyOwner{
airdroptoken = newToken;
}

function multiSend( address[]calldata recipients, uint256[]calldata amounts) external onlyOwner {
    require(recipients.length == amounts.length,"recipients not equal amounts");
    require(recipients.length <= 255,"To many adresses");
    require(amounts.length <= 255,"To many values");
    for (uint256 i = 0; i < recipients.length; i++) {
      // airdropToken.safeTransferFrom(address(msg.sender), recipients[i], amounts[i]);
    _safeTransfer(airdroptoken, recipients[i],amounts[i]);
    }
}

// function safeAirDropTransferFrom(address _token,address _from, address _to, uint256 amount)internal{
//   TransferHelper.safeTransferFrom(_token, _from, _to, amount);
// }
// function safeAirDropTransfer(address _token,address _to, uint256 amount)internal{
//   TransferHelper.safeTransfer(_token, _to, amount);
// }



function _safeTransfer(address token, address to, uint value) private {
  (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
  require(success && (data.length == 0 || abi.decode(data, (bool))), 'Token: TRANSFER_FAILED');
}
  




// function doBatchAirdrop(address[] calldata _addressesUsers, uint256[] _amountForEachUser) public returns(bool){
//   require(_addressesUsers.length == _amountForEachUser.length);
//   require(_addressesUsers.length <= 255,"To many adresses");
//   for(uint i = 0; i < _amountForEachUser; i++ ){
//     tokenInstance.transfer(_addressesUsers[i], _amountForEachUser[i]);
//   }
//   return true;
// }

// function doAirdrop(address[] calldata  _addressesUsers,uint256 _amountSum)public returns(bool) {
//   // require(_addressesUsers.length == _amountForEachUser.length);
//   require(_addressesUsers.length <= 255,"To many adresses");
//   // IERC20 token = IERC20(AirDropToken);
//   for (uint8 i; i < _addressesUsers.length; i++){
//   _amountSum = _amountSum.sub(_amountSum[i]);
//   AirDropToken.safeTransferFrom(address[],address(this),_amountForEachUser);
// }

// } 
// function awaitTokenApproveTheSend(address token, address[] recipients, uint256[] recipientsAmount, uint256 sumAmount) public {

// }

// function safeSDBTransfer(address _from,address _to, uint256 _amount)internal{
//   TransferHelper.safeTransfer(_from,_to, _amount);
// }
// function multiTransferToken_a4A(
//     address _token,
//     address[] calldata _addresses,
//     uint256[] calldata _amounts,
//     uint256 _amountSum
//   ) payable external whenNotPaused
//   {
//     require(_addresses.length == _amounts.length);
//     require(_addresses.length <= 255);
//     IERC20 token = IERC20(_token);
//     token.safeTransferFrom(msg.sender, address(this), _amountSum);
//     for (uint8 i; i < _addresses.length; i++) {
//       _amountSum = _amountSum.sub(_amounts[i]);
//       token.transfer(_addresses[i], _amounts[i]);
//     }
//   }
// }
}