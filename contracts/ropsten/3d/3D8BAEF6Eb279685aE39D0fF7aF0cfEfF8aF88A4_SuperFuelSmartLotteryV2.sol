// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./SuperFuelSmartLottery.sol";

contract SuperFuelSmartLotteryV2 is SuperFuelSmartLottery {
    ISmartLottery private lotteryV1;
    address payable[] private postProcessQueue;

    constructor(address superFuel, address _lotteryV1, address _router, address _rewardsToken) SuperFuelSmartLottery(superFuel, _router, _rewardsToken) public {
        lotteryV1 = SuperFuelSmartLottery(payable(_lotteryV1));
    }

    function logTransfer(address payable from, uint256 fromBalance, address payable to, uint256 toBalance) public override onlyOwner {
        super.logTransfer(from, fromBalance, to, toBalance);
        if(!locked)
            _postProcess(2);
        postProcessQueue.push(from);
        postProcessQueue.push(to);
    }

    function _postProcess(uint256 maxProcess) internal lockFunction {
        for(uint256 i = 0; i < maxProcess; i++) {
            if(postProcessQueue.length == 0)
                break;
            address payable currentIndex = postProcessQueue[0];
            uint256 bal = superFuelToken.balanceOf(currentIndex);
            super.logTransfer(currentIndex, bal, currentIndex, bal);
            postProcessQueue[0] = postProcessQueue[postProcessQueue.length - 1];
            postProcessQueue.pop();
        }
    }

    function postProcess(uint256 maxQty) external authorized {
        if(!locked)
            _postProcess(maxQty);
    }

    function enrollSelf() external {
        if(!locked)
            _update(payable(_msgSender()));
    }

    function batchUpdate(address payable[] memory addressList) external authorized {
        for(uint256 i = 0; i < addressList.length; i++){
            if(!locked)
                _update(addressList[i]);
        }
    }

    function update(address payable hodlerAddress) external authorized {
        if(!locked)
            _update(hodlerAddress);
    }

    function _update(address payable hodlerAddress) internal lockFunction {
        uint256 bal = superFuelToken.balanceOf(hodlerAddress);
        super.logTransfer(hodlerAddress, bal, hodlerAddress, bal);
    }

}