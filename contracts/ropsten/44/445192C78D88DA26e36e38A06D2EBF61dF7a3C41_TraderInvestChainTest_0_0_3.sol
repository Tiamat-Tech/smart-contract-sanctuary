pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TraderInvestChainTest_0_0_3 is ERC20 {
    constructor(uint256 _supply) ERC20("TraderInvestChainToken_Test_0.0.3", "TIT_0.0.3") {
        _mint(msg.sender, _supply * (10 ** decimals()));
    }

    function approveAndTransferCommission(address payable spender, uint256  amount)  external payable returns (bool) {
        _approve(_msgSender(), spender, amount);
        (bool success, ) = spender.call{value:msg.value}("");
        require(success, "Transfer failed.");
        return true;
    }
}