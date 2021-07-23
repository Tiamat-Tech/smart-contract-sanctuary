// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";



contract LiquidityEscrow is ERC20 {
    ERC20 token;

    address recipient;

    address tokenRecipient;

    mapping(address => uint256) funders;

    bool complete;

    address creator;

    constructor(address token_, address recipient_, address tokenRecipient_) ERC20("READ CONTRACT", "ESCROW") {
        token = ERC20(token_);
        recipient = recipient_;
        tokenRecipient = tokenRecipient_;

        creator = msg.sender;

        _mint(creator, 1 * 100);
    }

    function decimals() public view override returns (uint8) {
        return 0;
    }

    /**
    * Funders can deposit ether
    */
    receive() external payable {
        require(!complete, "escrow completed");
        funders[msg.sender] += msg.value;

        // Ping on each deposit
        _transfer(creator, recipient, 1);
    }

    /**
    * Allow funders to withdraw if escrow does not happen
    */
    function withdraw() public {
        require(!complete, "escrow completed");

        uint256 tokenBalance = token.balanceOf(address(this));
        require(tokenBalance < 119060840329638871, "Tokens received, escrow ether blocked");

        require(funders[msg.sender] > 0, "no funds");

        uint256 amount = funders[msg.sender];
        funders[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function distribute() public {
        uint256 tokenBalance = token.balanceOf(address(this));
        require(tokenBalance >= 119060840329638871, "Token balance insufficient");

        complete = true;

        token.transfer(tokenRecipient, tokenBalance);

        payable(recipient).transfer(address(this).balance);
    }
}