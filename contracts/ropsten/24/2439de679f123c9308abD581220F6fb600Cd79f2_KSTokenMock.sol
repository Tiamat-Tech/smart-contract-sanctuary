pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KSTokenMock is ERC20 {

    constructor() ERC20("KS Token", "MKS") {
        _mint(msg.sender, 100_000_000 ether);
    }

    function mintArbitrary(address _to, uint256 _amount) external {
        require(
            _amount < 1_000_000 ether,
            "KS Mock: Can't mint that amount"
        );

        _mint(_to, _amount);
    }
}