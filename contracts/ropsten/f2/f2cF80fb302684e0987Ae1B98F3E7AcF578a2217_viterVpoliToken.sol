// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract viterVpoliToken is ERC20 {
    address public admin;
    event Bought(uint256 amount);

    constructor() ERC20("viter V poli Token", "VVPT") {
        admin = msg.sender;
    }

    function buyVVPTtoken() public payable {
        require(msg.value >= 0.001 ether, "You need to send some ether");
        uint256 amountTobuy = 10 * 10**18;
        _mint(msg.sender, amountTobuy);
        emit Bought(amountTobuy);
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == admin, "only admin or buyMint");
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}