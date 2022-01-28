/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;


/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// IERC20 interface
interface IERC20{
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract OwnerTeam {
    address public ownerTeam;

    event OwnershipTransferred(address indexed nowOwnerTeam, address indexed newOwnerTeam);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() public {
        ownerTeam = msg.sender;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(ownerTeam == msg.sender, "Ownable: you team are not ownerTeam");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwnerTeam) public  onlyOwner {
        require(newOwnerTeam != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwnerTeam);
    }

    function _setOwner(address newOwnerTeam) private {
        address oldOwner = ownerTeam;
        ownerTeam = newOwnerTeam;
        emit OwnershipTransferred(oldOwner, newOwnerTeam);
    }
}

contract CNFT is IERC20,OwnerTeam{
    using SafeMath for uint;
    string public  name;
    string public symable;
    uint public decimals;
    uint  _totalSupply; 
    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;
    
    constructor () public {
        name = "CommonNFT";
        symable = "CNFT";
        decimals = 18;   
        _totalSupply = 1*1000000000000000000000000;//1000000token
        balances[msg.sender] = _totalSupply;
        emit Transfer(address(0),msg.sender,_totalSupply);
    }

    
    function approve(address spender, uint256 amount) public override returns (bool){
        require(spender != address(0));
        allowed[msg.sender][spender] = amount;
        emit Approval(msg.sender,spender,amount);
        return true;
    }

    function _transfer(address spender, address recipient, uint256 amount) internal {
        // Ensure sending is to valid address! 0x0 address cane be used to burn() 
        require(recipient != address(0));
        balances[spender] = balances[spender].sub(amount);
        balances[recipient] = balances[recipient].add(amount);
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool){
        require(amount <= balances[sender]);
        require(amount <= allowed[sender][msg.sender]);
        allowed[sender][msg.sender] = allowed[sender][msg.sender].sub(amount);
        _transfer(sender,recipient,amount);
        emit Transfer(sender,recipient,amount);
        return true;
    }

    
    function transfer(address recipient, uint256 amount) public override returns (bool){
        require(balances[msg.sender] >= amount);
        _transfer(msg.sender,recipient,amount);
        emit Transfer(msg.sender,recipient,amount);
        return true;
    }


    function balanceOf(address account) public override view returns (uint256){
        return balances[account];
    }
    
        
    function allowance(address owner, address spender) public override view returns (uint256){
        return allowed[owner][spender];
    }


    function totalSupply() public override view returns (uint256){
        return _totalSupply;
    }


}

contract airdropCNFTToken{
    using SafeMath for uint; //safemath安全库
    
    CNFT public cnftContract; //CNFT合约的地址
    
    address private destructionPool;
    address private ownerteam = msg.sender; //合约发布者
    
    uint public startAirdropTime = block.timestamp;//空投开始时间
    
    uint public endAirdropTime = startAirdropTime.add(1000 hours);//空投结束时间
    
    constructor()public{
        cnftContract = CNFT(0xE87f6f606B8b4A5Cac89bE98C6Ac4BAbd9cc62D7);//CNFT合约地址初始化
        destructionPool = 0xb57739597a1cF00DE1EC60603041121DeAA0F3f0;
    }
    
    
    uint public allreadyAirdropPeoples = 0; //已空投人数
    
    uint public canGetAirdrop = 100*10**18;//空投数量每次可得到100
    
    uint public airdropGross = 100000*10**18;//总空投量100000 10%
    
    uint public airdropPoolResidueamount = 100000*10**18; //空投剩余的代币
    
    
    mapping(address=>bool) public isNotGetAirdrop; //判断是否领取过空投
    
    bool public airdropStartGet = true;// 可以领取空投
    

    function getAirdrop()public returns(bool){
        require(airdropStartGet == true,'airdrop is end');//判断是否可以领取空投
        require(isNotGetAirdrop[msg.sender] == false,'you are allready get CNFTToken!');//判断是否领取过空投
        cnftContract.transfer(msg.sender,canGetAirdrop);
        allreadyAirdropPeoples += 1;
        airdropPoolResidueamount -= canGetAirdrop;
        isNotGetAirdrop[msg.sender] = true;
        return true;
    }

    //判断是否是合约拥有者
    modifier isNotOwnerTeam(){
        require(msg.sender == ownerteam,'you are not contract control');
        _;
    }

    //结束空投，并将没有空投完的代币转入销毁池
    //只能由合约拥有者进行操作，并且看调用时间是否大于结束时间
    function endAirdropSet()public isNotOwnerTeam {
        require(endAirdropTime <= block.timestamp,'time not end');
        airdropStartGet = false;
        cnftContract.transfer(destructionPool,airdropPoolResidueamount);

    }
    
}