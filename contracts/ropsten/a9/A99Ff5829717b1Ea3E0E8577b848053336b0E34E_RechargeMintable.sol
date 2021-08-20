// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RechargeBase.sol";
import "hardhat/console.sol";

contract RechargeMintable is RechargeBase {
    uint256 private _withdrawn;

    address rewardsRouter;

    event Deposit(address from, uint256 amount);
    event Withdraw(address to, uint256 amount);

    constructor (string memory name_, string memory symbol_) RechargeBase(name_, symbol_, 0, 0) {
    }

    function decimals() public view override returns (uint8) {
        return 18;
    }

    function fee() public pure override returns (uint256) {
        return 0;
    }

    function setRewardsRouter(address addr) public onlyOwner {
        rewardsRouter = addr;
    }

    function deposit(bool yield) public payable {
        require(msg.value > 0);

        uint256 rAmount;
        if (_tSupply == 0 || _rTotal == 0) {
            rAmount = msg.value * 10**18;
        } else {
            rAmount = reflectionFromToken(msg.value, fee());
        }

        if (!yield && (_tOwned[msg.sender] >= 0 || _rOwned[msg.sender] == 0)) {
            _addTokensToStaticBalance(msg.sender, msg.value, rAmount);
        }

        _mint(msg.value, rAmount);
        _rOwned[msg.sender] += rAmount;

//        console.log("Deposit: %s", msg.value);
//        console.log("Deposit: %s", tokenFromReflection(rAmount));
    }

    function withdraw(uint256 tAmount) public {
        uint256 tBalance = balanceOf(msg.sender);
        require(tBalance >= tAmount, "Insufficient balance");

        (uint256 rAmount, uint256 rTransferAmount , uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount, fee());

        if (_tOwned[msg.sender] > 0) {
            _subTokensFromStaticBalance(msg.sender, tAmount, rAmount);
        }

        // rAmount is different to tAmount requested

//        console.log("");
//        console.log("Address        %s", msg.sender);
//        console.log('withdraw       %s', tAmount);
//        console.log('rAmount in T   %s', tokenFromReflection(rAmount));
//        console.log('pre tOwned     %s', tokenFromReflection(_rOwned[msg.sender]));
//        console.log('pre _rOwned    %s', _rOwned[msg.sender]);
        if (tBalance == tAmount) {
            _rOwned[msg.sender] = 0;
        } else {
            _rOwned[msg.sender] -= rAmount;
        }
//        console.log('rAmount        %s', rAmount);
//        console.log('post _rOwned   %s', _rOwned[msg.sender]);
//
//        console.log("_tSupply        %s", _tSupply);
//        console.log("tAmount        %s", tAmount);

        // Complete withdrawal of the remaining funds resets contract to initial state
        uint256 sendAmount;

        if (_tSupply == tAmount) {
            sendAmount = tAmount;
        } else {
            sendAmount = tTransferAmount;
        }

        _burn(sendAmount, rAmount);

//        console.log("Post _tSupply    %s", _tSupply);
//        console.log('post tOwned %s', tokenFromReflection(_rOwned[msg.sender]));

        _withdrawn += sendAmount;

        (bool sent,) = payable(msg.sender).call{value: sendAmount}("");
        require(sent, "Failed send");

        emit Withdraw(msg.sender, sendAmount);
    }
}