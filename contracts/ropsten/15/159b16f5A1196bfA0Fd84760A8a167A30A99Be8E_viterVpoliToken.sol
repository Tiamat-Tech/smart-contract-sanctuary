// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract viterVpoliToken is ERC20 {
    address public admin;

    constructor() ERC20("viter V poli Token", "VVPT") {
        _mint(msg.sender, 1000 * 10**18);
        admin = msg.sender;
    }

    function transferVVPT(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == admin, "only admin");
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}