pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./libs/TransferHelper.sol";

contract TokenDistributor is Ownable {
    using TransferHelper for address;
    mapping(address => bool) operators;

    constructor() Ownable() {
        operators[msg.sender] = true;
    }

    function updateOpertaor(address _operator, bool _grant) external onlyOwner {
        operators[_operator] = _grant;
    }

    function distribute(
        address _token,
        address[] calldata _receivers,
        uint256[] calldata _amounts,
        uint256 total
    ) external onlyOperator {
        require(_receivers.length == _amounts.length, "LENGTH_DIFF");
        uint256 sentAmount;
        for (uint256 i; i < _receivers.length; i++) {
            uint256 amount = _amounts[i];
            require(amount > 0, "ZERO_AMOUNT");
            _token.safeTransfer(_receivers[i], amount);
            sentAmount += amount;
        }

        require(sentAmount == total, "SENT_AMOUNT_DIFF_TOTAL");
    }

    modifier onlyOperator() {
        require(operators[msg.sender] == true, "Only Operator");
        _;
    }
}