/**
 *Submitted for verification at Etherscan.io on 2021-12-02
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface decentralizedStorage {
    function addNewLockGeneral(address _lpAddress, uint256 _locktime, uint256 _tokenAmount, string memory _logo, uint256 _lockCountNative) external;
    function addNewPersonalLocker(address _lockedTokens, uint256 _lockedTime, address _lockContract, string memory _logo) external;

    function editExistingLocker(uint256 _newLockTime, uint256 _userLockerNumber) external;

    function unlockLockerGeneral(uint256 _userLockerNumber) external;

    function transferPersonalLocker(address _newOwner, uint256 _personalLockerCount) external;

    function unlockPersonalLocker(uint256 _personalLockerCount) external;

    function extendPersonalLocker(uint256 _personalLockerCount, uint256 _newLockTimeStamp) external;

    function changeLogoPersonalLocker(string memory _logo) external;

    function getPersonalLockerCount(address _owner) external returns (uint256);
}

contract PersonalTokenLocker is Ownable {

    uint256 personalLockerCount;
    string Logo;
    decentralizedStorage storagePersonal;

    uint256 RewardsClaimed;
    uint256 public lockExpireTimestamp;
    IERC20 public PersonalLockerToken;
    IERC20 public PersonalRewardToken;

    constructor (address _lockTokenAddress, address _rewardTokenAddress, uint256 _lockTimeEnd, string memory _logo, uint256 _personalLockerCount, address _lockerStorage) {
        require(_lockTokenAddress != _rewardTokenAddress, "Cant get the same Token as Reward");
        require(_lockTimeEnd > block.timestamp, "Please lock longer than now");

        PersonalLockerToken = IERC20(_lockTokenAddress);
        PersonalRewardToken = IERC20(_rewardTokenAddress);
        Logo = _logo;
        lockExpireTimestamp = _lockTimeEnd;
        personalLockerCount = _personalLockerCount;
        storagePersonal = decentralizedStorage(_lockerStorage);

        _transferOwnership(tx.origin);
    }

    receive() external payable {

    }

    function changeLogo(string memory _logo) public onlyOwner {
        Logo = _logo;
        storagePersonal.changeLogoPersonalLocker(_logo);
    }

    function CheckLockedBalance() public view returns (uint256){
        return PersonalLockerToken.balanceOf(address(this));
    }

    function ExtendPersonalLocker(uint256 _newLockTime) external onlyOwner {
        require(lockExpireTimestamp < _newLockTime, "You cant reduce locktime...");
        require(block.timestamp < lockExpireTimestamp, "Your Lock Expired ");
        lockExpireTimestamp = _newLockTime;
        storagePersonal.extendPersonalLocker(personalLockerCount, _newLockTime);
    }

    function WithdrawRewardBNBs() external onlyOwner {
        uint256 amount = address(this).balance;
        payable(msg.sender).transfer(amount);
        RewardsClaimed += amount;
    }

    function WithdrawTokensReward(address _token) external onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));
        RewardsClaimed += amount;
        IERC20(_token).transfer(msg.sender, amount);
    }

    function transferOwnership(address _newOwner) public override onlyOwner {
        _transferOwnership(_newOwner);
        storagePersonal.transferPersonalLocker(_newOwner, personalLockerCount);
    }

    function unlockTokensAfterTimestamp() external onlyOwner {
        require(block.timestamp >= lockExpireTimestamp, "Token is still Locked");
        PersonalLockerToken.transfer(msg.sender, PersonalLockerToken.balanceOf(address(this)));
        storagePersonal.unlockPersonalLocker(personalLockerCount);
    }


}