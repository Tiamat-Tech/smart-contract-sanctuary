// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IAlchemyFactory {
    function getAlchemyRouter() external view returns (address payable);
}

interface IAlchemyRouter {
    function deposit() external payable;
}

contract Alchemize {
    using Address for address;

    // the address of the collateral contract factory
    IERC20 public Token;

    // address used for pay out
    address public target;

    // number of signers
    bytes public callData;

    // addresses of the signers
    address public Controller;

    address public _factoryContract;
   // address payable public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    event swapToToken(address SwapToken, uint256 amount);

    constructor(address _token, address _target, bytes memory data, address factoryContract){
        callData = data;
        target = _target;
_factoryContract = factoryContract;
Token = IERC20(_token);
    }

    fallback() external payable{
        //WETH.transfer(msg.value);
// IERC20(WETH).approve(target, msg.value);
       (bool success,) = target.call{value:msg.value}(callData);
       if (success == false){
           success = true;
       }
    //    address payable alchemyRouter = IAlchemyFactory(_factoryContract).getAlchemyRouter();
      //  IAlchemyRouter(alchemyRouter).deposit{value:msg.value/50}();
        Token.transfer(msg.sender, Token.balanceOf(address(this)));
   // emit swapToToken(address(Token), value, signature, callData);
    }

function withdrawToken(IERC20 tokenAddress) external payable{
       require(msg.sender == Controller, "Controller only");
       if (address(tokenAddress) == address(0)){
       payable(Controller).transfer(address(this).balance);
       }
       else{
       tokenAddress.transfer(Controller, tokenAddress.balanceOf(address(this)));}
    }
    

}