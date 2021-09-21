//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StarxTimeLock {
    using SafeERC20 for IERC20;

    // ERC20 basic token contract being held
    IERC20 private _token;

    // contract owner address
    address private _owner;

    struct Frozen {
        address beneficiary;
        uint256 balance;
        uint256 releaseTime;
    }

    mapping(address => Frozen) frozens;

    event LogDeposit(address sender, address beneficiary, uint256 amount, uint256 releaseTime);
    event LogRelease(address receiver, uint256 amount);

    constructor(address __token) {
        _token = IERC20(__token);
        _owner = msg.sender;
    }

    modifier ownerOnly(){
        require(_owner == msg.sender, "caller is not the owner");
        _;
    }

    /**
     * @return the token being held.
     */
    function token() public view virtual returns (IERC20) {
        return _token;
    }

    function deposit(address beneficiary, uint256 amount, uint256 releaseTime) public returns(bool success) {
        token().safeTransferFrom(msg.sender, address(this), amount);
        frozens[beneficiary].beneficiary = beneficiary;
        frozens[beneficiary].balance = frozens[beneficiary].balance + amount;
        frozens[beneficiary].releaseTime = releaseTime;
        emit LogDeposit(msg.sender, beneficiary, amount, releaseTime);
        return true;
    }

    function release(address beneficiary) public returns(bool success) {
        require(frozens[beneficiary].balance > 0, "no tokens to release");
        require(block.timestamp >= frozens[beneficiary].releaseTime, "current time is before release time");
        token().safeTransfer(beneficiary, frozens[beneficiary].balance);
        return true;
    }

    function updateReleaseTime(address beneficiary, uint256 releaseTime) public ownerOnly returns(bool success) {
        require(frozens[beneficiary].balance > 0, "address doesn't have frozen balance");
        require(frozens[beneficiary].releaseTime > block.timestamp, "release time is before current time");
        frozens[beneficiary].releaseTime = releaseTime;
        return true;
    }
    
    function getData(address beneficiary) public view returns(Frozen memory){
        require(frozens[beneficiary].balance > 0, "address doesn't have frozen balance");
        return frozens[beneficiary];
    }

}