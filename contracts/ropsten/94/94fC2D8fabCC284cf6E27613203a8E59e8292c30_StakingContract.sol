pragma solidity ^0.8.0;
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';


contract StakingContract{
    using SafeMath for uint256;
    using Address for address;
    address reserveContract;
    address mindpayToken;
    address admin;
    mapping(address => uint256) stakedEtherBalanceOf;
    mapping(address => uint256) stakedTokenBalanceOf;

    constructor(address _mindpayToken) public{
        mindpayToken = _mindpayToken;
        admin = msg.sender;
    }

    function setReserveContract(address _reserveContract) external{
        require(admin == msg.sender, "Only admin");
        reserveContract = _reserveContract;
    }
    function depositToken(address depositer, uint256 amount) external{
        require(msg.sender == reserveContract, "Only reserve contract can call this function");
        IERC20(mindpayToken).transferFrom(msg.sender, address(this), amount);
        stakedTokenBalanceOf[depositer] = stakedTokenBalanceOf[depositer].add(amount);
    }

    receive() external payable{}
    function depositEther(address depositer, uint256 amount) external{
        require(msg.sender == reserveContract, "Only reserve contract can call this function");
        stakedEtherBalanceOf[depositer] = stakedEtherBalanceOf[depositer].add(amount);
    } 

}