pragma solidity 0.5.2;
import '@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol';
contract Token is ERC20Mintable {
       string public name = "FINNET USD TEST";
       string public symbol = "FUSDT";
       uint8 public decimals = 18;
}