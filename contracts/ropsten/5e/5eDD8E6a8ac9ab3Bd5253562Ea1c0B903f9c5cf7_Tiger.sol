import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract Tiger is ERC20 {
    constructor() ERC20("Tiger", "Tiger") {
        _mint(msg.sender, 1000000*10**18);
    }
}