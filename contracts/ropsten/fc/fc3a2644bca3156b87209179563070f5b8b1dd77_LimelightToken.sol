pragma solidity ^0.8.7;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 * @notice https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/math/SafeMath.sol
 */
import "./token/ERC20/ERC20.sol";
import "./token/ERC20/IERC20.sol";
import "./token/ERC20/extensions/IERC20Metadata.sol";

library SafeMath {
  /**
   * SafeMath mul function
   * @dev function for safe multiply
   **/
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }
  
  /**
   * SafeMath div funciotn
   * @dev function for safe devide
   **/
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }
  
  /**
   * SafeMath sub function
   * @dev function for safe subtraction
   **/
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }
  
  /**
   * SafeMath add fuction 
   * @dev function for safe addition
   **/
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract LimelightToken is ERC20 {
  string public constant NAME = "Limelight Token";
  string public constant SYMBOL = "LMLT";
  uint256 public constant INITIAL_SUPPLY = 10000000000 * 10**18;
  
 constructor() ERC20(NAME, SYMBOL) {
    _mint(msg.sender, INITIAL_SUPPLY);
    
  }
}