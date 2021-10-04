//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Escrow {
    using SafeMath for uint256;

    address public client;
    address public developer;
    address public agent;

    IERC20 public currency;

    uint public amount;
    uint public fee;
    uint internal constant PERCENTAGE = 100;

    bool private hasStarted = false;
    bool private delivered = false; 
    bool public disputed = false;

    constructor(address _client, address _developer, uint _fee) {
        require(
            address(_client) == _client,
            "constructor :: invalid client address"
        );

        require(
            address(_developer) == _developer,
            "constructor :: invalid developer address"
        );

        client = _client;
        developer = _developer;
        agent = msg.sender;

        fee = _fee;
    }

    function workMission(IERC20 _currency, uint _amount) public {
        require(
            msg.sender == client,
            "workMission :: only client can start work"
        );

        require(
            !hasStarted,
            "workMission :: you have already started a work contract"
        );

        require(
            _currency.balanceOf(msg.sender) >= _amount,
            "workMission :: invalid balance amount of currency"
        );

        _currency.transferFrom(msg.sender, address(this), _amount);

        currency = _currency;
        amount = _amount;
        hasStarted = true;
    }

    function receivePayment() public {
        require(
            msg.sender == developer,
            "receivePayment :: only developer can confirm delivery"
        );

        require(
            delivered == true,
            "receivePayment :: the work has not been delivered to the client yet"
        );

        uint commission = amount.div(PERCENTAGE).mul(fee);
        uint payment = amount.div(PERCENTAGE).mul(PERCENTAGE - fee);
        
        currency.transferFrom(address(this), developer, payment);
        currency.transferFrom(address(this), agent, commission);

        disputed = false;
        hasStarted = false;
        delivered = false;
    }

    function confirmDelivery() public {
        require(
            msg.sender == client,
            "confirmDelivery :: only client can confirm work delivery"
        );

        delivered = true;
    }

    function settleDispute(address settleTo) public {
        require(
            msg.sender == agent,
            "settleDispute :: only agent can settle dispute"
        );

        require(
            settleTo == client || settleTo == developer,
            "settleDispute :: settle address should match client or developer"
        );

        require(
            disputed == true,
            "settleDispute :: noone has disputed"
        );

        currency.transferFrom(address(this), settleTo, currency.balanceOf(address(this)));
        disputed = false;
        hasStarted = false;
        delivered = false;
    }

    function dispute() public {
        require(
            msg.sender == developer || msg.sender == client,
            "dispute :: only client or developer can dispute"
        );

        require(
            disputed = false,
            "dispute :: there is currently a dispute in progress"
        );

        disputed = true;
    }
}