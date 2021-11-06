import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OurCoin is ERC20 {
    constructor() ERC20("The Coin", "THE") {
        _mint(msg.sender, 121 * 10 ** decimals());
    }
}