pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./EIP712MetaTransaction.sol";

contract VoteToken is ERC20, EIP712MetaTransaction {
    uint256 public initialSupply = 100000000000000000000;

    constructor()
        public
        ERC20("AAiT Vote", "VOT")
        EIP712MetaTransaction("GineteToken", "1", 3)
    {
        _mint(msg.sender, initialSupply);
    }

		// helper function
    function mint(uint256 supply) external {
        _mint(_msgSender(), supply);
    }
}