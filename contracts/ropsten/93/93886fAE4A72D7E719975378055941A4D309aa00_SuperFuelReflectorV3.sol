// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./utils/NoBSDynamicReflector.sol";

contract SuperFuelReflectorV3 is NoBSDynamicReflector {
    address payable[] private postProcessQueue;

    constructor(address _lpRouter, address _controlToken, address _rewardsToken) NoBSDynamicReflector(_lpRouter, _controlToken, _rewardsToken) AuthorizedListExt(true) public {

    }

    function logTransfer(address payable from, uint256 fromBalance, address payable to, uint256 toBalance) public onlyOwner {
        setShares(from, fromBalance, to, toBalance);
        if(!locked)
            _postProcess();
        postProcessQueue.push(from);
        postProcessQueue.push(to);
    }

    function setShare(address shareholder, uint256 amount) external override onlyOwner {
        _setShare(shareholder, amount);
        if(!locked && postProcessQueue.length > 3)
            _postProcess();
        postProcessQueue.push(payable(shareholder));
    }

    function _postProcess() internal lockFunction {

        if(postProcessQueue.length == 0)
                return;

        for(uint256 i = 0; i < postProcessQueue.length; i++) {
            address payable currentIndex = postProcessQueue[i];
            uint256 bal = controlToken.balanceOf(currentIndex);
            _setShare(currentIndex, bal);
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
        uint256 bal = controlToken.balanceOf(hodlerAddress);
        _setShare(hodlerAddress, bal);
    }

}