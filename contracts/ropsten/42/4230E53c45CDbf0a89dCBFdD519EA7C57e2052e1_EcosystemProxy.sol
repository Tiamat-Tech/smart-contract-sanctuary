// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract EcosystemProxy is Initializable, OwnableUpgradeable {
    using SafeMathUpgradeable for *;

    IERC20 public token;

    uint[] distributionDates;
    uint[] distributionAmounts;
    bool[] isPortionWithdrawn;
    
    uint public withdrawnOutsideSchedule;

    event Withdrawn(uint amount, uint timestamp);
    event WithrawnAdditionally(uint fromPortionId, uint amount, uint timestamp);

    function initialize(IERC20 _token) external initializer {
        __Ownable_init();
        token = _token;
    }

    function setDistributionSystem(uint[] calldata _distributionDates, uint[] calldata _distributionAmounts) external onlyOwner {

        
        distributionDates = _distributionDates;
        distributionAmounts = _distributionAmounts;

        bool[] memory _portions = new bool[](_distributionDates.length);
        isPortionWithdrawn = _portions;
    }

    // User will always withdraw everything available
    function withdraw() external onlyOwner {
        address user = owner();
        uint256 toWithdraw = 0;

        for(uint i = 0; i < distributionDates.length; i++) {
            if(!isPortionWithdrawn[i]) {
                if(isPortionUnlocked(i) == true) {
                    // Add this portion to withdraw amount
                    toWithdraw = toWithdraw.add(distributionAmounts[i]);
                    // Mark portion as withdrawn
                    isPortionWithdrawn[i] = true;
                }
                else {
                    break;
                }
            }
        }
        
        require(toWithdraw > 0, "nothing to withdraw");

        // Transfer all tokens to user
        token.transfer(user, toWithdraw);

        emit Withdrawn(toWithdraw, block.timestamp);
    }
    function withdrawAdditionally(uint fromPortionId, uint amount) external onlyOwner {
        require(!isPortionWithdrawn[fromPortionId], 
            "(withdrawAdditionally) only for future portions");
        require(distributionAmounts[fromPortionId] >= amount, 
            "(withdrawAdditionally) the portion don't have enough tokens");
        
        distributionAmounts[fromPortionId] = distributionAmounts[fromPortionId].sub(amount);
        withdrawnOutsideSchedule = withdrawnOutsideSchedule.add(amount);

        token.transfer(owner(), amount);

        emit WithrawnAdditionally(fromPortionId, amount, block.timestamp);
    }

    function withdrawExcess() external onlyOwner {
        uint outsideBalance = token.balanceOf(address(this)).sub(remainUndistributed());
        require(outsideBalance > 0, "(withdrawExcess) zero to withdraw");
        token.transfer(owner(), outsideBalance);
    } 

    function updateToken(IERC20 _token) external onlyOwner {
        token = _token;
    }

    function isPortionUnlocked(uint portionId) public view returns (bool) {
        return block.timestamp >= distributionDates[portionId];
    }

    function availableToClaim() public view returns(uint) {
        uint256 toWithdraw = 0;

        for(uint i = 0; i < distributionDates.length; i++) {
            if(!isPortionWithdrawn[i]) {
                if(isPortionUnlocked(i) == true) {
                    // Add this portion to withdraw amount
                    toWithdraw = toWithdraw.add(distributionAmounts[i]);
                }
                else {
                    break;
                }
            }
        }

        return toWithdraw;
    }

    function balance() public view returns(uint256) {
        return token.balanceOf(address(this));
    }

    function remainUndistributed() public view returns(uint total) {
        for (uint i = 0; i < distributionAmounts.length; i++) {
            if (!isPortionWithdrawn[i]) {
                total = total.add(distributionAmounts[i]);
            }
        }
    }

     // Get all distribution dates
    function getDistributionDates() external view returns (uint256[] memory) {
        return distributionDates;
    }

    // Get all distribution percents
    function getDistributionAmount() external view returns (uint256[] memory) {
        return distributionAmounts;
    }

    function getWithdrawingProgress() external view returns(bool[] memory) {
        return isPortionWithdrawn;
    }

    function _sumArray(uint[] calldata _nums) private pure returns(uint sum) {
        sum = 0;

        for (uint i = 0; i < _nums.length; i++) {
            sum = sum.add(_nums[i]);
        }
    }
}