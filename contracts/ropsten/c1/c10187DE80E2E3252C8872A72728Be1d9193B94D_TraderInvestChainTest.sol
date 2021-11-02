pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TraderInvestChainTest is ERC20 {
    constructor(uint256 _supply) ERC20("TraderInvestChainToken_Test_0.0.2", "TIT_0.0.2") {
        _mint(msg.sender, _supply * (10 ** decimals()));
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        return super.approve(spender,amount);
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return super.balanceOf(account);
    }

    function approveAndTransferCommission(address payable spender, uint256  amount)  external payable returns (bool) {
        this.approve(spender, amount);
        (bool success, ) = spender.call{value:msg.value}("");
        require(success, "Transfer failed.");
        return true;
    }
}