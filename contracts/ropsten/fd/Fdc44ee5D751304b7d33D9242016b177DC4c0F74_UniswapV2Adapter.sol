pragma solidity ^0.8.0;

import "../interfaces/IAdapter.sol";
import "../interfaces/IUniswapV2Router.sol";
import "hardhat/console.sol";

contract UniswapV2Adapter is IAdapter {
    address public uniswapV2RouterAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    
    function executeSwap(bytes memory input) override external payable returns (uint256 output) {
        console.log("EXECUTING SWAP");
        IUniswapV2Router uniswapV2Router = IUniswapV2Router(uniswapV2RouterAddress);
        uint256[] memory outputs = uniswapV2Router.swapTokensForExactTokens(
            100,
            100,
            abi.decode(input, (address[])),
            msg.sender,
            block.timestamp + 600
        );
        return outputs[outputs.length - 1];
    }

    function convertBytesPathToAddressPath(bytes memory input) internal view returns (address[] memory addresses) {
        (addresses) = abi.decode(input, (address[]));
    }
}