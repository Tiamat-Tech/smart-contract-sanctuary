// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TokenFarming.sol";

contract Factory is Ownable {
    event FarmingDeployed(
        address _farming,
        address _stakeToken,
        address _distributionToken,
        uint256 _rewardPerBlock,
        uint256 _deployTime
    );

    uint256 maxFarmingDuration;

    IERC20 feeToken;
    uint256 feeAmount;

    function updateMaxFarmingDuration(uint256 _newMaxFarmingDuration) external onlyOwner {
        maxFarmingDuration = _newMaxFarmingDuration;
    }

    function updatefeeToken(address _newFeeToken) external onlyOwner {
        feeToken = IERC20(_newFeeToken);
    }

    function updateFeeAmount(uint256 _newFeeAmount) external onlyOwner {
        feeAmount = _newFeeAmount;
    }

    function deployFarmingContract(
        address _stakeToken,
        address _distributionToken,
        uint256 _rewardPerBlock,
        uint256 _duration
    ) external returns (address) {
        require(maxFarmingDuration > 0, "Factory: maxFarmingDuration cannot be zero");
        require(_duration > 0, "Factory: duration cannot be zero");
        require(_duration <= maxFarmingDuration, "Factory: invalid duration");

        uint256 _endDate = block.timestamp + _duration;

        feeToken.transferFrom(msg.sender, address(this), feeAmount);

        TokenFarming _farming =
            new TokenFarming(_stakeToken, _distributionToken, _rewardPerBlock, _endDate);
        _farming.transferOwnership(msg.sender);

        emit FarmingDeployed(
            address(_farming),
            _stakeToken,
            _distributionToken,
            _rewardPerBlock,
            _endDate
        );
        return address(_farming);
    }

    function withdrawFee(
        IERC20 _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        require(_token.transfer(_to, _amount), "Factory: Transfer failed");
    }
}