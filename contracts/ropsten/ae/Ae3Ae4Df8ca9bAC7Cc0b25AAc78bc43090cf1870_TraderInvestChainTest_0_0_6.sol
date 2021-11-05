pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TraderInvestChainTest_0_0_6 is ERC20 {

    constructor(uint256 _supply) ERC20("TraderInvestChainToken_Test_0.0.6", "TIT_0.0.6") {
        _mint(msg.sender, _supply * (10 ** decimals()));
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    function approveAndTransferCommission(address payable spender, uint256  amount)  public payable returns (bool) {
        _approve(_msgSender(), spender, amount);
        (bool success, ) = spender.call{value:msg.value}("");
        require(success, "Transfer failed.");
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    function sellToken(
        address sender,
        address recipient,
        uint256 amount) public payable returns (bool) {
            transferFrom(sender, recipient, amount);
        (bool success, ) = sender.call{value:msg.value}("");
        require(success, "Transfer failed.");
        return true;
    }

}