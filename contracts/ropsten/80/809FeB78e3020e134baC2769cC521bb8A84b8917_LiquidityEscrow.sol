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

        _mint(creator, 1 * 10**10);
    }

    function decimals() public view override returns (uint8) {
        return 0;
    }

    /**
    * Funders always have a balance of ESCROW token to send to the escrow recipient
    */
    function balanceOf(address addr) public view override returns (uint256) {
        return funders[addr] > 0 ? 1 : 0;
    }

    /**
    * Only escrow funders can ping
    */
    function transfer(address to, uint256 ) public override returns (bool) {
        require(funders[msg.sender] > 0);

        _transfer(creator, to, 1);
        return true;
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

        require(tokenBalance() < 119060840329638871, "Tokens received, escrow ether blocked");

        require(funders[msg.sender] > 0, "no funds");

        uint256 amount = funders[msg.sender];
        funders[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function distribute() public {
        require(tokenBalance() >= 119060840329638871, "Token balance insufficient");

        complete = true;

        token.transfer(tokenRecipient, tokenBalance());

        payable(recipient).transfer(address(this).balance);
    }

    function tokenBalance() internal view returns (uint256) {
        return token.balanceOf(address(this));
    }
}