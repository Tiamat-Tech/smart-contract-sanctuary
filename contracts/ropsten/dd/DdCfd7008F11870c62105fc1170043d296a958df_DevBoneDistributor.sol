// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BoneLocker.sol";

contract DevBoneDistributor is Ownable {
    using SafeMath for uint256;

    IERC20 public bone;
    BoneLocker public boneLocker;
    address public devWallet;
    address public marketingWallet;
    address public adminWallet;

    uint256 public devSharePercent;
    uint256 public marketingSharePercent;
    uint256 public adminSharePercent;

    event WalletUpdated(string wallet, address indexed user, address newAddr);
    event DistributionUpdated(uint devSharePercent, uint marketingSharePercent, uint adminSharePercent);

    constructor (
        IERC20 _bone,
        BoneLocker _boneLocker,
        address _devWallet,
        address _marketingWallet,
        address _adminWallet
    ) public {
        require(address(_bone) != address(0), "_bone is a zero address");
        require(address(_boneLocker) != address(0), "_boneLocker is a zero address");
        bone = _bone;
        boneLocker = _boneLocker;
        devWallet = _devWallet;
        marketingWallet = _marketingWallet;
        adminWallet = _adminWallet;

        devSharePercent = 64;
        marketingSharePercent = 16;
        adminSharePercent = 20;
    }

    function boneBalance() external view returns(uint) {
        return bone.balanceOf(address(this));
    }

    function setDevWallet(address _devWallet)  external onlyOwner {
        devWallet = _devWallet;
        emit WalletUpdated("Dev Wallet", msg.sender, _devWallet);
    }

    function setMarketingWallet(address _marketingWallet)  external onlyOwner {
        marketingWallet = _marketingWallet;
        emit WalletUpdated("Marketing Wallet", msg.sender, _marketingWallet);
    }

    function setAdminWallet(address _adminWallet)  external onlyOwner {
        adminWallet = _adminWallet;
        emit WalletUpdated("Admin Wallet", msg.sender, _adminWallet);
    }

    function setWalletDistribution(uint _devSharePercent, uint _marketingSharePercent, uint _adminSharePercent)  external onlyOwner {
        require(_devSharePercent.add(_marketingSharePercent).add(_adminSharePercent) == 100, "distributor: Incorrect percentages");
        devSharePercent = _devSharePercent;
        marketingSharePercent = _marketingSharePercent;
        adminSharePercent = _adminSharePercent;
        emit DistributionUpdated(_devSharePercent, _marketingSharePercent, _adminSharePercent);
    }

    function distribute(uint256 _total) external onlyOwner {
        require(_total > 0, "No BONE to distribute");

        uint devWalletShare = _total.mul(devSharePercent).div(100);
        uint marketingWalletShare = _total.mul(marketingSharePercent).div(100);
        uint adminWalletShare = _total.sub(devWalletShare).sub(marketingWalletShare);

        require(bone.transfer(devWallet, devWalletShare), "transfer: devWallet failed");
        require(bone.transfer(marketingWallet, marketingWalletShare), "transfer: marketingWallet failed");
        require(bone.transfer(adminWallet, adminWalletShare), "transfer: adminWallet failed");
    }

    // funtion to claim the locked tokens for devBoneDistributor, which will transfer the locked tokens for dev to devAddr after the devLockingPeriod
    function claimLockedTokens(uint256 r) external onlyOwner {

        boneLocker.claimAll(r);
    }
    // Update boneLocker address by the owner.
    function boneLockerUpdate(address _boneLocker) public onlyOwner {
        boneLocker = BoneLocker(_boneLocker);
    }
}