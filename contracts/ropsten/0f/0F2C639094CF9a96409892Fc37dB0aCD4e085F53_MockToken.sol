import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Inheriting from ERC20 gives us basic fungible token methods
// https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#core
contract MockToken is ERC20 {
  // Constructor is run once upon deploying SC... used to set intial state
  constructor() ERC20("MockToken", "MOK") {
    // In the constructor... msg.sender is the owner of smart contract
  }

  function mint(uint256 amount) public {
    _mint(msg.sender, amount);
  }
}