pragma solidity ^0.8.0;
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';


contract LiquidityContract{
    using SafeMath for uint256;
    using Address for address;
    address public reserveContract;
    address public admin;

    constructor() public{
        admin = msg.sender;
    }

    function setReserveContract(address _reserveContract) external{
        require(admin == msg.sender, "Only admin");
        reserveContract = _reserveContract;
    }

    receive() external payable{
        require(
            msg.sender == reserveContract || msg.sender == admin, 
            "Only Reserve Contract/Admin can call this function"
        );
    }
}