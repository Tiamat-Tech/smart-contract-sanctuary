pragma solidity ^0.8.0;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';

contract Mindpay is ERC20{
    using SafeMath for uint256;
    using Address for address;
    address admin;
    address public reserveContract;
    constructor() public ERC20('Mindpay','MDP'){
        admin = msg.sender;
    }

    function setReserveContract(address _reserveContract) external{
        require(admin == msg.sender, "Only admin");
        reserveContract = _reserveContract;
    }

    function mint(address recipient, uint amount) external{
        require(msg.sender == reserveContract, "Only Reserve Contract can mint tokens");
        _mint(recipient, amount);
    }

    function burn(address recipient, uint amount) external{
        require(msg.sender == reserveContract, "Only Reserve Contract can burn tokens");
        _burn(recipient, amount);
    }
}