// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./SafeERC20.sol";

contract TokenVesting is Ownable {
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

    event NewGrantValue(
        address indexed to,
        uint256 _value,
        uint256 _start,
        uint256 _cliff,
        uint256 _end,
        uint256 value
    );
    event UnlockedTokens(address indexed to, uint256 value);

    constructor(IERC20 token_) {
        token = token_;
    }

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

        totalVesting = totalVesting + _value;
        emit NewGrantValue(_to, _value, _start, _cliff, _end, totalVesting);
    }

    function unlockedVesting() external {
        Grant storage grant_ = grants[msg.sender];
        require(grant_.value > 0);

        transferable = calculateVestedToken();

        grant_.transferred = grant_.transferred + (transferable);
        totalVesting = totalVesting - (transferable);

        token.safeTransfer(msg.sender, transferable);
        emit UnlockedTokens(msg.sender, transferable);
    }

    function calculateVestedToken() public returns (uint256 calculateValue) {
        Grant storage _grant = grants[msg.sender];
        if (block.timestamp > _grant.cliff) {
            return 0;
        }
        if (block.timestamp > _grant.end) {
            return _grant.value;
        }

        uint256 amountVest = (_grant.value * (block.timestamp - _grant.start)) /
            (_grant.end);
        if (amountVest == 0) {
            return 0;
        }
        //console.log(amountVest);
        transferable = amountVest - _grant.transferred;
        if (transferable == 0) {
            return 0;
        }

        return transferable;
    }
}