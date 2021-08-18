//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Stake is Ownable, Pausable, ERC1155Holder {
    using SafeERC20 for IERC20;

    // collateral token address
    address private immutable _stake;

    // reward token address, ERC1155 only
    address private immutable _reward;

    enum LevelId {
        A,
        B,
        C,
        D
    }

    struct RewardLevel {
        // array of reward token id
        uint256[] ids;
        // amount to be staked
        uint112 amount;
        // account lock seconds
        uint32 lockSeconds;
    }

    // reward levels
    mapping(LevelId => RewardLevel) private _levels;

    struct Account {
        // collateral amount
        uint128 amount;
        // account unlock time
        uint32 unlockAt;
    }

    // mapping for address to Account
    mapping(address => Account) private _accounts;

    constructor(address stakeToken, address rewardToken) Ownable() {
        require(stakeToken != address(0), "stakeToken 0");
        _stake = stakeToken;

        require(rewardToken != address(0), "rewardToken 0");
        _reward = rewardToken;
    }

    function setRewardLevel(
        LevelId levelId,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        uint112 amount,
        uint32 lockSeconds
    ) external onlyOwner {
        IERC1155 erc = IERC1155(_reward);
        erc.safeBatchTransferFrom(msg.sender, address(this), ids, amounts, "");
        _levels[levelId].ids = ids;
        _levels[levelId].amount = amount;
        _levels[levelId].lockSeconds = lockSeconds;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function recoverRewardToken(
        uint256[] calldata ids,
        uint256[] calldata amounts,
        address to
    ) external onlyOwner {
        IERC1155 erc = IERC1155(_reward);
        erc.safeBatchTransferFrom(address(this), to, ids, amounts, "");
    }

    function recoverStakeToken(address to) external onlyOwner {
        uint256 amount = IERC20(_stake).balanceOf(address(this));
        IERC20(_stake).safeTransfer(to, amount);
    }

    /**
     * @dev stake and receive reward
     * @param levelId level id
     * @param to reward receiver
     */
    function stake(LevelId levelId, address to) external whenNotPaused {
        RewardLevel storage level = _levels[levelId];
        require(level.ids.length > 0, "!exist");
        Account storage account = _accounts[msg.sender];
        require(account.unlockAt < block.timestamp, "exist");
        uint112 amount = level.amount;
        IERC20(_stake).safeTransferFrom(msg.sender, address(this), amount);
        IERC1155 rToken = IERC1155(_reward);

        for (uint256 i; i < level.ids.length; i++) {
            if (rToken.balanceOf(address(this), level.ids[i]) > 0) {
                rToken.safeTransferFrom(address(this), to, level.ids[i], 1, "");
                account.amount = amount;
                account.unlockAt += uint32(block.timestamp + level.lockSeconds);
                emit Staked(msg.sender, levelId);
                return;
            }
        }

        require(false, "!reward");
    }

    function unstake(address to) external whenNotPaused {
        require(
            _accounts[msg.sender].unlockAt < uint32(block.timestamp),
            "locked"
        );
        address account = msg.sender;
        IERC20(_stake).safeTransfer(to, _accounts[account].amount);
        emit Unstaked(msg.sender, to, _accounts[account].amount);
        delete _accounts[account];
    }

    function accountOf(address owner)
        external
        view
        returns (uint256 amount, uint32 unlockAt)
    {
        amount = _accounts[owner].amount;
        unlockAt = _accounts[owner].unlockAt;
    }

    function getRewardLevels()
        external
        view
        returns (uint256[] memory amounts, RewardLevel[] memory levels)
    {
        levels = new RewardLevel[](4);

        levels[0] = _levels[LevelId.A];
        levels[1] = _levels[LevelId.B];
        levels[2] = _levels[LevelId.C];
        levels[3] = _levels[LevelId.D];

        amounts = new uint256[](4);
        amounts[0] = getRewardCountByLevelId(LevelId.A);
        amounts[1] = getRewardCountByLevelId(LevelId.B);
        amounts[2] = getRewardCountByLevelId(LevelId.C);
        amounts[3] = getRewardCountByLevelId(LevelId.D);
    }

    function getRewardCountByLevelId(LevelId levelId)
        public
        view
        returns (uint256 amount)
    {
        RewardLevel storage level = _levels[levelId];
        if (level.ids.length == 0) {
            return 0;
        }
        IERC1155 token = IERC1155(_reward);
        for (uint256 i; i < level.ids.length; i++) {
            amount += token.balanceOf(address(this), level.ids[i]);
        }
    }

    event Staked(address indexed owner, LevelId indexed levelId);

    event Unstaked(address indexed owner, address indexed to, uint256 amount);
}