pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenMock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 100_000_000 ether);
    }

    function mintArbitrary(address _to, uint256 _amount) external {
        require(
            _amount < 1_000_000 ether,
            "Token Mock: Can't mint that amount"
        );
        _mint(_to, _amount);
    }
}