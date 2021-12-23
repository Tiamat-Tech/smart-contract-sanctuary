// pragma solidity ^0.8.0;
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract AtosToken is ERC20 {
//     constructor() ERC20("ExampleToken", "EGT") {
//         _mint(msg.sender, 10000 * 10**decimals());
//     }
// }
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AtosToken is ERC20 {
    constructor() ERC20("AtosToken", "AST") {
        _mint(msg.sender, 10000 * 10**decimals());
    }
}