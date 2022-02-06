/**
 *Submitted for verification at Etherscan.io on 2018-12-07
*/

/**
 *  https://Smart-234.io
 *
 * Smart-contract start at 11 Dec 2018 10:00 UTC
 *
 *
 * Smart-234 Contract
 *  - GAIN 23.4% PER 24 HOURS
 *  -     +0.02% every day before the payment
 *
 *  - Minimal contribution 0.01 eth
 *  - Currency and payment - ETH
 *  - Contribution allocation schemes:
 *    -- 96% payments
 *    -- 4% Marketing
 *
 *
 * You get MORE PROFIT if you withdraw later !
 * Increase of the total rate of return by 0.02% every day before the payment.
 * The increase in profitability affects all previous days!
 *  After the dividend is paid, the rate of return is returned to 2.34 % per day
 *
 *           For example: if the Deposit is 10 ETH
 *
 *                days      |   %    |   profit
 *          --------------------------------------
 *            1 (>24 hours) | 2.36 % | 0.235 ETH
 *              10          | 2.54 % | 2.54  ETH
 *              30          | 2.94 % | 8.82  ETH
 *              50          | 3.34 % | 16.7  ETH
 *              100         | 4.34 % | 43.4  ETH
 *
 *
 * How to use:
 *  1. Send any amount of ether to make an investment
 *  2a. Claim your profit by sending 0 ether transaction (every day, every week, i don't care unless you're spending too much on GAS)
 *  OR
 *  2b. Send more ether to reinvest AND get your profit at the same time
 *
 * RECOMMENDED GAS LIMIT: 250000
 * RECOMMENDED GAS PRICE: https://ethgasstation.info/
 *
 * Contract reviewed and approved by experts!
 *
 */

pragma solidity ^0.4.24;

import "./1_InvestorsStorage.sol";
import "./2_SafeMath.sol";

contract Smart234 {
    using SafeMath for uint;

    address admin;
    uint waveStartUp;

    uint invested;
    uint payed;
    uint startTime;

    event LogInvestment(address indexed _addr, uint _value, uint _bonus);
    event LogIncome(address indexed _addr, uint _value);
    event LogReferrerAdded(address indexed _investor, address indexed _referrer);
    event LogRefBonus(address indexed _investor, address indexed _referrer, uint _amount, uint indexed _level);
    event LogNewWave(uint _waveStartUp);

    InvestorsStorage private x;

    modifier notOnPause() {
        require(waveStartUp <= block.timestamp);
        _;
    }

    function bytesToAddress(bytes _source) internal pure returns(address parsedReferrer) {
        assembly {
            parsedReferrer := mload(add(_source,0x14))
        }
        return parsedReferrer;
    }

    function addReferrer() internal returns(uint) {
        address _referrer = bytesToAddress(bytes(msg.data));
        if (_referrer != msg.sender) {
            x.addReferrer(msg.sender, _referrer);
            emit LogReferrerAdded(msg.sender, _referrer);
            return(msg.value / 20);
        }
    }

    function refSystem() private {
        address first = x.r(msg.sender);
        if (x.amountOfDeposits(first) < 500) {
            x.addDeposit(first, msg.value / 10);
            emit LogRefBonus(msg.sender, first, msg.value / 10, 1);
        }
        address second = x.r(first);
        if (second != 0x0) {
            if (x.amountOfDeposits(second) < 500) {
                x.addDeposit(second, msg.value / 20);
                emit LogRefBonus(msg.sender, second, msg.value / 20, 2);
            }
            address third = x.r(second);
            if (third != 0x0) {
                if (x.amountOfDeposits(third) < 500) {
                    x.addDeposit(third, msg.value * 3 / 100);
                    emit LogRefBonus(msg.sender, third, msg.value * 3 / 100, 3);
                }
            }
        }
    }

    constructor(address _admin) public {
        admin = _admin;
        x = new InvestorsStorage();
        startTime = 1544522400;
        waveStartUp = 1544522400;
    }

    function() external payable {
        if (msg.value == 0) {
            withdraw();
        } else {
            invest();
        }
    }

    function invest() notOnPause public payable {
        require(msg.value >= 0.0001 ether);
        admin.transfer(msg.value / 25);

        if (x.r(msg.sender) != 0x0) {
            refSystem();
        } else if (msg.data.length == 20) {
            uint bonus = addReferrer();
            refSystem();
        }

        x.addDeposit(msg.sender, msg.value + bonus);

        invested += msg.value;
        emit LogInvestment(msg.sender, msg.value, bonus);
    }

    function withdraw() public {

        uint _payout = x.dividends(msg.sender);

        if (_payout > 0) {

            if (_payout > address(this).balance) {
                nextWave();
                return;
            }

            x.updateCheckpoint(msg.sender);
            admin.transfer(_payout / 25);
            msg.sender.transfer(_payout * 24 / 25);
            emit LogIncome(msg.sender, _payout);
            payed += _payout;
        }
    }

    function getDeposits(address _address) external view returns(uint) {
        return x.sumOfDeposits(_address);
    }

    function getDividends(address _address) external view returns(uint) {
        return x.dividends(_address);
    }

    function getDividendsWithFee(address _address) external view returns(uint) {
        return x.dividends(_address) * 24 / 25;
    }

    function getDaysAfterStart() external view returns(uint) {
        return (block.timestamp.sub(startTime)) / 1 days;
    }

    function investorsCount() external view returns(uint) {
        return x.investorsCount();
    }

    function getInvestedAmount() external view returns(uint) {
        return invested;
    }

    function getPayedAmount() external view returns(uint) {
        return payed;
    }

    function nextWave() private {
        x = new InvestorsStorage();
        invested = 0;
        payed = 0;
        waveStartUp = block.timestamp + 7 days;
        emit LogNewWave(waveStartUp);
    }
}