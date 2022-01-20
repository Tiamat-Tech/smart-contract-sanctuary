// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./base/MultiToken.sol";

contract AssetManagerUniswap is MultiToken("(AdamUniswap)") {

    mapping(address => mapping(uint => uint)) public strategyBalances;
    mapping(uint => uint) public totalBalances;

    function depositERC20(ERC20 token, uint amount) external {
        TransferHelper.safeTransferFrom(address(token), msg.sender, address(this), amount);

        if(!mintedContracts[address(token)]) {
            _createToken(address(token), token.name(), 18);
        }

         _mint(msg.sender, addressToId[address(token)], amount, "");
        strategyBalances[msg.sender][addressToId[address(token)]] += amount;
        totalBalances[addressToId[address(token)]] += amount;
    }
}