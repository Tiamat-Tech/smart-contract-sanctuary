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

contract DestructionPool {
    using SafeMath for uint256; //safemath安全库

    CNFT public cnftContract; //CNFT合约的地址

    // 30天锁仓时间
    uint256 timeLockTime = 30 days;

    // 开启时间
    uint256 public thisMonthStartTime = block.timestamp;

    // 结束时间
    uint256 public thisMonthEndTime = thisMonthStartTime.add(timeLockTime);

    address private ownerTeam;//合约发布者

    constructor(address _cnftContract) public {
        cnftContract = CNFT(_cnftContract); //CNFT合约地址初始化
        ownerTeam = msg.sender;
    }

    struct SendTokenspoople {
        address sendPeople;
        uint256 tokens;
    }

    SendTokenspoople[] public sendTokenspooples;

    //最大捐赠者的id
    uint256 public maxTokensId;

    //发送要销毁的代币数量，并对销毁者进行记录
    function sendTokensToDestructionPool(uint256 _amount) public {
        require(block.timestamp < thisMonthEndTime,"this activity is end");
        require(
            cnftContract.balanceOf(msg.sender) > 0,
            "you are not owner CNFTtoken ,please buy something"
        );
        // must cnftContract approve;
        cnftContract.transferFrom(msg.sender, address(this), _amount);
        SendTokenspoople memory sendTokenspoople = SendTokenspoople({
            sendPeople: msg.sender,
            tokens: _amount
        });
        sendTokenspooples.push(sendTokenspoople);
    }

    // 目前销毁代币数量最多的人的id
    function ownerTeamMaxGetId() public returns (uint256) {
        require(msg.sender == ownerTeam,'you are not contract owner');
        uint256 max = sendTokenspooples[0].tokens;
        for (uint256 i = 0; i < sendTokenspooples.length; i++) {
            if (max < sendTokenspooples[i].tokens) {
                max = sendTokenspooples[i].tokens;
                maxTokensId = i;
            }
        }
        return maxTokensId;
    }

    //销毁最多代币数量的人领取奖金 漏洞
    function maxTokensIdGetReward() public {
        require(
            msg.sender == sendTokenspooples[maxTokensId].sendPeople,
            "you are not this pool maxGetId"
        );
        cnftContract.transfer(msg.sender, DestructionPoolBalance() / 10);
        maxTokensId = 0;
    }


    //  开始活动
    function openThisActiveReward() public {
        require(msg.sender == ownerTeam, "you are not this contract ownerTeam");
        thisMonthStartTime = block.timestamp;
        thisMonthEndTime = thisMonthStartTime.add(timeLockTime);
    }

    // 查看最大贡献量的地址和捐赠的数量
    function maxGetId() public view returns (uint256, address) {
        uint256 max = sendTokenspooples[0].tokens;
        address seeMaxTokenAddress;
        for (uint256 i = 0; i < sendTokenspooples.length; i++) {
            if (max < sendTokenspooples[i].tokens) {
                max = sendTokenspooples[i].tokens;
                seeMaxTokenAddress = sendTokenspooples[i].sendPeople;
            }
        }
        return (max, seeMaxTokenAddress);
    }

    //查询销毁池的余额
    function DestructionPoolBalance() public view returns (uint256) {
        return cnftContract.balanceOf(address(this));
    }
    
    function SendTokenspooplesLength() public view returns(uint){
        return sendTokenspooples.length;
    }
}

contract HotOnePool{

    CNFT public cnftContract;
    DestructionPool public Destruction;
    address ownerTeam;
    constructor()public{
        cnftContract = CNFT(address(0xE87f6f606B8b4A5Cac89bE98C6Ac4BAbd9cc62D7));
        Destruction = DestructionPool(address(0xb57739597a1cF00DE1EC60603041121DeAA0F3f0));
        ownerTeam = msg.sender;
    }

    struct rewardOwner{
        address NftContract;
        string nftName;
        string url;
        address owner;
        uint  nftHotNumber;
        uint rewardtime;
    }
    //这个月的榜单
    mapping(uint => rewardOwner) public  thisMonthRanking;
    //历史榜单
    // mapping(uint => rewardOwner) public historyRanking;
    rewardOwner[] public historyRanking;

    function writeRankingFirst(address firstContract,string memory firstName,string memory firstUrl,address firstOwner,uint firstNftHotNumber)public virtual onlyOwner{
        thisMonthRanking[1].NftContract = firstContract;
        thisMonthRanking[1].nftName =firstName;
        thisMonthRanking[1].url =firstUrl;
        thisMonthRanking[1].owner =firstOwner;
        thisMonthRanking[1].nftHotNumber =firstNftHotNumber;
        thisMonthRanking[1].rewardtime =block.timestamp;
        historyRanking.push(rewardOwner(firstContract,firstName,firstUrl,firstOwner,firstNftHotNumber,block.timestamp));
    }

    function writeRankingSecond(address secondContract,string memory secondName,string memory secondUrl,address secondOwner,uint secondNftHotNumber)public virtual onlyOwner{
        thisMonthRanking[2].NftContract = secondContract;
        thisMonthRanking[2].nftName =secondName;
        thisMonthRanking[2].url =secondUrl;
        thisMonthRanking[2].owner =secondOwner;
        thisMonthRanking[2].nftHotNumber =secondNftHotNumber;
        thisMonthRanking[2].rewardtime =block.timestamp;
        historyRanking.push(rewardOwner(secondContract,secondName,secondUrl,secondOwner,secondNftHotNumber,block.timestamp));
    }

    function writeRankingThird(address thirdContract,string memory thirdName,string memory thirdUrl,address thirdOwner,uint thirdNftHotNumber)public virtual onlyOwner{
        thisMonthRanking[3].NftContract = thirdContract;
        thisMonthRanking[3].nftName =thirdName;
        thisMonthRanking[3].url =thirdUrl;
        thisMonthRanking[3].owner =thirdOwner;
        thisMonthRanking[3].nftHotNumber =thirdNftHotNumber;
        thisMonthRanking[3].rewardtime =block.timestamp;
        historyRanking.push(rewardOwner(thirdContract,thirdName,thirdUrl,thirdOwner,thirdNftHotNumber,block.timestamp));
    }

    function transferReward() public virtual onlyOwner {
        cnftContract.transfer(thisMonthRanking[1].owner,hotOnePoolTokenBalance()/2);
        cnftContract.transfer(thisMonthRanking[2].owner,hotOnePoolTokenBalance()/2);
        cnftContract.transfer(thisMonthRanking[3].owner,hotOnePoolTokenBalance()/2);
        cnftContract.transfer(address(Destruction),hotOnePoolTokenBalance());
    }


    modifier onlyOwner() {
        require(ownerTeam == msg.sender, "Ownable: caller is not the owner");
        _;
    }


    function hotOnePoolTokenBalance()public view returns(uint){
        return cnftContract.balanceOf(address(this));
    }



}