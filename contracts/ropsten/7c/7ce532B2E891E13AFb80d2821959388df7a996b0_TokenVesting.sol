// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "hardhat/console.sol";

contract TokenVesting is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 private token;
    struct Grant {
        uint256 value;
        uint256 start;
        uint256 cliff;
        uint256 end;
        uint256 transferred;
    }

    mapping(address => Grant) public grants;

    uint256 public totalVesting;
    uint256 public transferable;
    uint256 public vested;

    constructor(IERC20 token_) {
        token = token_;
    }

    /*function getAmount(Grant memory _grant) external {
        _grant.transferred = _grant.transferred.add(transferable);
        totalVesting = totalVesting.sub(transferable);

        token.transfer(msg.sender, transferable);
    }*/

    function granting(
        address _to,
        uint256 _value,
        uint256 _start,
        uint256 _cliff,
        uint256 _end
    ) external onlyOwner {
        require(_value > 0);

        require(grants[_to].value == 0);
        // Assign a new grant.
        grants[_to] = Grant({
            value: _value,
            start: _start,
            cliff: _cliff,
            end: _end,
            transferred: 0
        });

        totalVesting = totalVesting.add(_value);
    }

    function unlockedVesting() public returns (uint256 transferAmount) {
        Grant storage grant_ = grants[msg.sender];
        require(grant_.value > 0);

        vested = calculateVestedToken(grant_);

        if (vested == 0) {
            return 0;
        }

        transferable = vested.sub(grant_.transferred);

        if (transferable == 0) {
            return 0;
        }
        grant_.transferred = grant_.transferred.add(transferable);
        totalVesting = totalVesting.sub(transferable);

        token.transfer(msg.sender, transferable);

        /*uint256 transferedAmount = getAmount(grant_);
        return transferedAmount;*/
    }

    function calculateVestedToken(Grant memory _grant)
        public
        view
        returns (uint256 calculateValue)
    {
        if (block.timestamp > _grant.cliff) {
            return 0;
        }
        if (block.timestamp > _grant.end) {
            return _grant.value;
        }

        uint256 amountVest = _grant
            .value
            .mul(block.timestamp.sub(_grant.start))
            .div(_grant.end);
        //console.log("-----", amountVest);
        return amountVest;
    }
}