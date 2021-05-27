pragma solidity 0.6.12;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract TeamToken is ERC20 {
    using SafeMath for uint256;
    
    uint256 constant FEE_DENOMINATOR = 1000; 
 
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _supply,
        address _owner,
        address _feeWallet, 
        uint256 _feePercentage
    ) public ERC20(_name, _symbol) {
        _setupDecimals(_decimals);
        uint256 fee = _supply.mul(_feePercentage).div((FEE_DENOMINATOR.mul((100))));
        _mint(_feeWallet, fee);       
        _mint(_owner, _supply.sub(fee));
    }
}