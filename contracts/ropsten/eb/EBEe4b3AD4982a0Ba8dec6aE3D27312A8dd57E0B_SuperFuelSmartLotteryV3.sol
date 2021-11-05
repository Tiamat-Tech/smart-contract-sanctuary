// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./SuperFuelSmartLottery.sol";

contract SuperFuelSmartLotteryV3 is SuperFuelSmartLottery {
    SuperFuelSmartLottery private lotteryV1;
    address payable[] private postProcessQueue;

    constructor(address superFuel, address _lotteryV1, address _router, address _rewardsToken) SuperFuelSmartLottery(superFuel, _router, _rewardsToken) public {
        lotteryV1 = SuperFuelSmartLottery(payable(_lotteryV1));
        draw = lotteryV1.draw();
        for(uint256 i = 1; i < draw; i++) {
            (string memory name, address add, uint drawNo, uint prize) = lotteryV1.winnersByRound(i);
            winnersByRound[i] = WinnerLog(name, add, drawNo, prize);
        }
    }

    function logTransfer(address payable from, uint256 fromBalance, address payable to, uint256 toBalance) public override onlyOwner {
        _logTransfer(from, fromBalance, to, toBalance);
        if(!locked)
            _postProcess();
        postProcessQueue.push(from);
        postProcessQueue.push(to);
    }

    function _postProcess() internal lockFunction {

        if(postProcessQueue.length == 0)
                return;

        for(uint256 i = 0; i < postProcessQueue.length; i++) {
            address payable currentIndex = postProcessQueue[i];
            uint256 bal = superFuelToken.balanceOf(currentIndex);
            _logTransfer(payable(deadAddress), 0, currentIndex, bal);
        }
        delete postProcessQueue;
    }

    function postProcess() external authorized {
        if(!locked)
            _postProcess();
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
        _logTransfer(payable(deadAddress), 0, hodlerAddress, bal);
    }

}