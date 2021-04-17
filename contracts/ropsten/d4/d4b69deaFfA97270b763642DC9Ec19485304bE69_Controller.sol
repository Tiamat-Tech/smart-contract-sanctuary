pragma solidity ^0.6.2;

import "./interference/ERC20.sol";
import "./interference/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Controller is Ownable {

    using SafeMath for uint256;
    
    //token Fees

    uint256 public comissionFee = 1000;

    function setComissionFee(uint256 _amount) public onlyOwner {
        comissionFee = _amount;
    }

    // token INIT

    mapping(string => ERC20) public tokens;

    function tTokenInit(string memory _coin, address _token) public onlyOwner {
        tokens[_coin] = ERC20(_token);
    }

    // Mint Logic

    struct Queue {
        string coin;
        address addr;
        uint256 amount;
        string txnhash;
    }

    Queue[] public userMints;

    mapping(string => uint256) public timestampSolver;
    mapping(string => uint256) public timestampController;

    function mintCoin(
        string memory _coin,
        address _userAddress,
        uint256 _amount,
        string memory _txnhash,
        uint256 _lastTimestamp
    ) public onlyOwner {
        Queue memory m;
        m.coin = _coin;
        m.addr = _userAddress;
        m.amount = _amount;
        m.txnhash = _txnhash;

        userMints.push(m);

        uint256 sendamount = _amount.sub(_amount.div(comissionFee));

        timestampSolver[_coin] = _lastTimestamp;
        timestampController[_coin] = block.timestamp;

        tokens[_coin].mint(_userAddress, sendamount);
    }

    function laginsec(string memory _coin) public view returns (uint256) {
        return timestampController[_coin].sub(timestampSolver[_coin]);
    }

    /// Burn logic
    struct QueueBlock {
        string coin;
        string addr;
        uint256 amount;
        bool success;
        string txnhash;
    }

    QueueBlock[] public userWithdraws;

    function registerWithdrawal(
        string memory _coin,
        string memory _address,
        uint256 _amount
    ) public returns (uint256 arrayLength) {
        require(_amount <= tokens[_coin].balanceOf(msg.sender), "no balance");
        require(
            _amount <= tokens[_coin].allowance(msg.sender, address(this)),
            "no allowance"
        );

        tokens[_coin].burnFrom(msg.sender, _amount);

        uint256 sendamount = _amount.sub(_amount.div(comissionFee));

        QueueBlock memory m;
        m.coin = _coin;
        m.addr = _address;
        m.amount = sendamount;
        m.success = false;
        m.txnhash = "x";

        userWithdraws.push(m);

        return userWithdraws.length;
    }

    function registerWithdrawalSuccess(uint256 _queue, string memory txnhash)
        public
        onlyOwner
    {
        userWithdraws[_queue].success = true;
        userWithdraws[_queue].txnhash = txnhash;
    }
}