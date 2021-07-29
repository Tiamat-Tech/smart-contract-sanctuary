// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TokenFarming.sol";

contract Factory is Ownable {
    event FarmingDeployed(address _farming);

    function deployFarmingContract(
        address _stakeToken,
        address _distributionToken,
        uint256 _rewardPerBlock
    ) external onlyOwner returns (address) {
        TokenFarming _farming = new TokenFarming(_stakeToken, _distributionToken, _rewardPerBlock);
        _farming.transferOwnership(msg.sender);

        emit FarmingDeployed(address(_farming));
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