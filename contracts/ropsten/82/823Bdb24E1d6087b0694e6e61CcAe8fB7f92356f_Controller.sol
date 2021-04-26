// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./interfaces/ERC20.sol";
import "./interfaces/Ownable.sol";
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
    mapping(string => bool) public transactionsProceeded;

    function mintCoin(
        string memory _coin,
        address _userAddress,
        uint256 _amount,
        string memory _txnhash,
        uint256 _lastTimestamp
    ) public onlyOwner {
        if (transactionsProceeded[_txnhash] == false) {
            if (timestampSolver[_coin] <= _lastTimestamp) {
                uint256 sendamount = _amount.sub(_amount.div(comissionFee));

                Queue memory m;
                m.coin = _coin;
                m.addr = _userAddress;
                m.amount = _amount;
                m.txnhash = _txnhash;

                userMints.push(m);

                timestampSolver[_coin] = _lastTimestamp;
                tokens[_coin].mint(_userAddress, sendamount);

                transactionsProceeded[_txnhash] = true;
            }
        }
    }

    function getMintsLength() public view returns (uint256) {
        return userMints.length;
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

    function getBurnsLength() public view returns (uint256) {
        return userWithdraws.length;
    }
}