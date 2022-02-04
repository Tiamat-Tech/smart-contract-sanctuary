// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ICreature.sol";
import "./interfaces/IRandomizer.sol";
import "./interfaces/IProtectionProgram.sol";

/// @title ProtectionProgram contract
contract ProtectionProgram is IProtectionProgram, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;

    struct Params {
        address creatureContract;
        address randomizerContract;
        address farmTokenContract;
        uint256 totalTenureScore;
        uint256 currentRewardPerTenure;
        uint256 bankerRewardPerSecond;
        uint128 taxPercent;
        uint128 stealOnWithdrawChance;
        uint64 withdrawLockupPeriod;
    }

    struct BankerStake {
        address owner;
        uint64 interactionTimestamp;
    }

    struct RebelStake {
        address owner;
        uint256 tenure;
        uint256 baseRewardByTenure;
    }

    Params public params;
    mapping(uint256 => BankerStake) public nftToBankerStake;
    mapping(uint256 => RebelStake) public nftToRebelStake;

    mapping(address => EnumerableSet.UintSet) private nftOwnerToNftNumber;

    /// @dev START storage for tenure groups.
    mapping(uint256 => uint256[]) public tenureGroupToRebels;
    mapping(uint256 => uint256) public rebelIndexInGroup;
    mapping(uint256 => bool) public isTenureGroupExist;
    uint256[] public tenureGroups;
    /// @dev END storage for tenure groups.

    /// @dev START view variables.
    uint256 public bankersInProgram;
    uint256 public rebelsInProgram;
    uint256 public farmTokenShared;
    /// @dev END view variables.

    constructor(
        address _creatureContract,
        address _randomizerContract,
        address _farmTokenContract
    ) {
        params.creatureContract = _creatureContract;
        params.randomizerContract = _randomizerContract;
        params.farmTokenContract = _farmTokenContract;
    }

    modifier onlyEOA() {
        address _sender = msg.sender;
        require(_sender == tx.origin, "ProtectionProgram: invalid sender (1).");

        uint256 size;
        assembly {
            size := extcodesize(_sender)
        }
        require(size == 0, "ProtectionProgram: invalid sender (2).");

        _;
    }

    /// @notice Set bankers reward for each second.
    /// @param _bankerRewardPerSecond Reward per second. Wei.
    function setBankerRewardPerSecond(uint256 _bankerRewardPerSecond) external override onlyOwner {
        require(_bankerRewardPerSecond > 0, "ProtectionProgram: bankers reward can't be a zero.");

        params.bankerRewardPerSecond = _bankerRewardPerSecond;
    }

    /// @notice Set tax percent for rebels. When bankers claim rewards, part of rewards (tax) are collected by the rebels.
    /// @param _taxPercent Percent in decimals. Where 10^27 = 100%.
    function setTaxPercent(uint128 _taxPercent) external override onlyOwner {
        require(_taxPercent > 0 && _taxPercent < _getDecimals(), "ProtectionProgram: invalid percent value.");

        params.taxPercent = _taxPercent;
    }

    /// @notice When banker claim reward, rebels have a chance to steal all of them. Set this chance
    /// @param _stealOnWithdrawChance Chance. Where 10^27 = 100%
    function setStealOnWithdrawChance(uint128 _stealOnWithdrawChance) external override onlyOwner {
        require(
            _stealOnWithdrawChance > 0 && _stealOnWithdrawChance < _getDecimals(),
            "ProtectionProgram: invalid withdraw chance."
        );

        params.stealOnWithdrawChance = _stealOnWithdrawChance;
    }

    /// @notice Bankers can withdraw funds if they have not claim rewards for a certain period of time.
    /// @param _withdrawLockupPeriod Time. Seconds.
    function setWithdrawLockupPeriod(uint64 _withdrawLockupPeriod) external override onlyOwner {
        params.withdrawLockupPeriod = _withdrawLockupPeriod;
    }

    /// @notice Add nfts to protection program.
    /// @dev Will be added only existed nfts where sender is nft owner.
    /// @param _nums Nfts nums.
    function add(uint256[] calldata _nums) external override {
        require(_nums.length > 0, "ProtectionProgram: array is empty.");

        ICreature _creatureContract = ICreature(params.creatureContract);

        uint256 _currentRewardPerTenure = params.currentRewardPerTenure;
        uint256 _tenureScoreByNums;
        uint256 _rebelsAdded;
        uint256 _bankersAdded;
        for (uint256 i = 0; i < _nums.length; i++) {
            uint256 _num = _nums[i];

            if (_num == 0) continue;
            if (msg.sender != _creatureContract.ownerOf(_num)) continue;

            _creatureContract.transferFrom(msg.sender, address(this), _num);
            nftOwnerToNftNumber[msg.sender].add(_num);

            if (_creatureContract.isRebel(_num)) {
                (uint256 _tenureScore,,,,) = _creatureContract.getRebelInfo(_num);
                nftToRebelStake[_num] = RebelStake(msg.sender, _tenureScore, _currentRewardPerTenure);

                // START add _num to tenure groups
                rebelIndexInGroup[_num] = tenureGroupToRebels[_tenureScore].length;
                tenureGroupToRebels[_tenureScore].push(_num);

                if (!isTenureGroupExist[_tenureScore]) {
                    isTenureGroupExist[_tenureScore] = true;
                    tenureGroups.push(_tenureScore);
                }
                // END add _num to tenure groups

                _tenureScoreByNums += _tenureScore;
                _rebelsAdded++;

                emit RebelAdded(_num);
            } else {
                nftToBankerStake[_num] = BankerStake(msg.sender, uint64(block.timestamp));
                _bankersAdded++;

                emit BankerAdded(_num);
            }
        }

        params.totalTenureScore += _tenureScoreByNums;
        bankersInProgram += _bankersAdded;
        rebelsInProgram += _rebelsAdded;
    }

    /// @notice Claim rewards for selected nfts
    /// @dev Sender should be nft owner. Nft should be in the protection program
    /// @param _nums Nfts nums
    function claim(uint256[] calldata _nums) external override {
        _claim(_nums, false);
    }

    /// @notice Claim rewards for selected nfts and withdraw from protection program
    /// @dev Sender should be nft owner. Nft should be in the protection program
    /// @param _nums Nfts nums
    function withdraw(uint256[] calldata _nums) external override onlyEOA {
        _claim(_nums, true);
    }

    /// @notice Calculate reward amount for nfts. On withdraw, part of reward can be stolen.
    /// @dev Sender should be nft owner. Nft should be in the protection program
    /// @param _nums Nfts nums
    /// @return bankersReward Rewards for all bankers
    /// @return rebelsReward Rewards for all rebels
    function calculateRewards(uint256[] calldata _nums)
        external
        view
        override
        returns (uint256 bankersReward, uint256 rebelsReward)
    {
        (bankersReward, rebelsReward, , ) = _calculateRewards(_nums, false);
    }

    /// @notice Return address of random rebel owner, dependent on rebel tenure score.
    function getRandomRebel() external override returns (address) {
        uint256 _totalTenureScore = params.totalTenureScore;
        if (_totalTenureScore == 0) return address(0);

        uint256 _rand = IRandomizer(params.randomizerContract).random(params.totalTenureScore);

        uint256 _l = tenureGroups.length;
        uint256 _tenureValue;
        uint256 _groupLength;
        uint256 _totalWeight;
        for (uint256 i = 0; i < _l; i++) {
            _tenureValue = tenureGroups[i];
            _groupLength = tenureGroupToRebels[_tenureValue].length;
            _totalWeight += _groupLength * _tenureValue;

            if (_rand < _totalWeight) {
                return nftToRebelStake[tenureGroupToRebels[_tenureValue][_rand % _groupLength]].owner;
            }
        }

        return address(0);
    }

    /// @notice Withdraw native token from contract
    /// @param _to Token receiver
    function withdrawNative(address _to) external override onlyOwner {
        payable(_to).transfer(address(this).balance);
    }

    /// @notice Transfer stuck ERC20 tokens.
    /// @param _token Token address
    /// @param _to Address 'to'
    /// @param _amount Token amount
    function withdrawStuckERC20(
        IERC20 _token,
        address _to,
        uint256 _amount
    ) external override onlyOwner {
        _token.transfer(_to, _amount);
    }

    /// @notice Return array with nfts by owner.
    /// @param _address Address.
    /// @param _from Index from.
    /// @param _amount Nfts amount in array.
    function getNftsByOwner(address _address, uint256 _from, uint256 _amount) external view override returns(uint256[] memory, bool[] memory) {
        uint256 _totalCount = nftOwnerToNftNumber[_address].length();
        if (_from + _amount > _totalCount) _amount = _totalCount - _from;

        ICreature _creature = ICreature(params.creatureContract);
        uint256[] memory _nfts = new uint256[](_amount);
        bool[] memory _isRebel = new bool[](_amount);
        uint256 _k = _from;
        for (uint256 i = 0; i < _amount; i++) {
            uint256 _num = nftOwnerToNftNumber[_address].at(_k);
            _nfts[i] = _num;
            _isRebel[i] = _creature.isRebel(_num);
            _k++;
        }

        return (_nfts, _isRebel);
    }

    function _claim(uint256[] calldata _nums, bool _isWithdraw) private {
        (
            uint256 _bankersReward,
            uint256 _rebelsReward,
            uint256 _currentRewardPerTenure,
            bool[] memory _isNumsRebel
        ) = _calculateRewards(_nums, _isWithdraw);

        ICreature _creatureContract = ICreature(params.creatureContract);
        uint256 _tenureToDelete;
        uint256 _bankersToWithdraw;
        uint256 _rebelsToWithdraw;
        // @dev _nums should be only bankers or rebels (nfts must exist)
        for (uint256 i = 0; i < _nums.length; i++) {
            if (_isNumsRebel[i]) {
                if (_isWithdraw) {
                    _rebelsToWithdraw++;
                    _tenureToDelete += _withdrawRebel(_creatureContract, _nums[i]);

                    nftOwnerToNftNumber[msg.sender].remove(_nums[i]);
                }
                else nftToRebelStake[_nums[i]].baseRewardByTenure = _currentRewardPerTenure;

                emit RebelClaimed(_nums[i], _isWithdraw);
            } else {
                if (_isWithdraw) {
                    _bankersToWithdraw++;
                    _withdrawBanker(_creatureContract, _nums[i]);

                    nftOwnerToNftNumber[msg.sender].remove(_nums[i]);
                }
                else nftToBankerStake[_nums[i]].interactionTimestamp = uint64(block.timestamp);

                emit BankerClaimed(_nums[i], _isWithdraw);
            }
        }

        // START UPDATE storage part
        params.currentRewardPerTenure = _currentRewardPerTenure;
        params.totalTenureScore -= _tenureToDelete;
        bankersInProgram -= _bankersToWithdraw;
        rebelsInProgram -= _rebelsToWithdraw;
        // END UPDATE storage part

        // START transfer farming token
        IERC20 _farmTokenContract = IERC20(params.farmTokenContract);

        uint256 _contractBalance = _farmTokenContract.balanceOf(address(this));
        uint256 _totalReward = _bankersReward + _rebelsReward;

        if (_contractBalance < _totalReward) _totalReward = _contractBalance;
        if (_totalReward > 0) _farmTokenContract.transfer(msg.sender, _totalReward);
        farmTokenShared += _totalReward;

        emit TokensClaimed(_nums, _isWithdraw);
        // END transfer farming token
    }

    function _calculateRewards(uint256[] calldata _nums, bool _isWithdraw)
        private
        view
        returns (
            uint256 _totalBankersReward,
            uint256 _totalRebelsReward,
            uint256,
            bool[] memory _isNumsRebel
        )
    {
        Params memory _params = params;
        _isNumsRebel = new bool[](_nums.length);

        for (uint256 i = 0; i < _nums.length; i++) {
            if (i > 0) require(_nums[i] > _nums[i - 1], "ProtectionProgram: invalid sequence of numbers in the array.");

            if (msg.sender == nftToBankerStake[_nums[i]].owner) {
                (uint256 _bankerReward, uint256 _rewardPerTenure) = _calculateBankerReward(
                    _nums[i],
                    _params,
                    _isWithdraw
                );

                _totalBankersReward += _bankerReward;
                _params.currentRewardPerTenure += _rewardPerTenure;
            } else if (msg.sender == nftToRebelStake[_nums[i]].owner) {
                _totalRebelsReward += _calculateRebelReward(_nums[i], _params.currentRewardPerTenure);
                _isNumsRebel[i] = true;
            } else {
                revert("ProtectionProgram: nft is not on the contract or caller is not a token owner.");
            }
        }

        return (_totalBankersReward, _totalRebelsReward, _params.currentRewardPerTenure, _isNumsRebel);
    }

    function _calculateBankerReward(
        uint256 _num,
        Params memory _params,
        bool _isWithdraw
    ) private view returns (uint256 _claimAmount, uint256 _rewardPerTenure) {
        uint256 _taxAmount;
        uint64 _interactionTimestamp = nftToBankerStake[_num].interactionTimestamp;
        _claimAmount = _params.bankerRewardPerSecond * (block.timestamp - _interactionTimestamp);

        if (_isWithdraw)
            require(
                _interactionTimestamp + _params.withdrawLockupPeriod < block.timestamp,
                "ProtectionProgram: wait until the lockout period is over."
            );

        if (_params.totalTenureScore > 0) {
            if (
                _isWithdraw &&
                IRandomizer(_params.randomizerContract).random(_getDecimals(), _num) < _params.stealOnWithdrawChance
            ) {
                _taxAmount = _claimAmount;
                _claimAmount = 0;
            } else {
                _taxAmount = (_claimAmount * _params.taxPercent) / _getDecimals();
                _claimAmount -= _taxAmount;
            }

            _rewardPerTenure = _taxAmount / _params.totalTenureScore;
        }

        return (_claimAmount, _rewardPerTenure);
    }

    function _calculateRebelReward(uint256 _num, uint256 _currentRewardPerTenure) private view returns (uint256) {
        return nftToRebelStake[_num].tenure * (_currentRewardPerTenure - nftToRebelStake[_num].baseRewardByTenure);
    }

    function _withdrawBanker(ICreature _creatureContract, uint256 _num) private {
        delete nftToBankerStake[_num];

        _creatureContract.safeTransferFrom(address(this), msg.sender, _num);
    }

    function _withdrawRebel(ICreature _creatureContract, uint256 _num) private returns (uint256) {
        uint256 _tenureScore = nftToRebelStake[_num].tenure;

        // Delete main stake struct
        delete nftToRebelStake[_num];

        // START clear rebel group info
        uint256 _rebelsInGroup = tenureGroupToRebels[_tenureScore].length;
        if (_rebelsInGroup > 1) {
            tenureGroupToRebels[_tenureScore][rebelIndexInGroup[_num]] = tenureGroupToRebels[_tenureScore][
                _rebelsInGroup - 1
            ];
        }
        tenureGroupToRebels[_tenureScore].pop();
        delete rebelIndexInGroup[_num];

        if (_rebelsInGroup == 1) {
            uint256 _l = tenureGroups.length;
            for (uint256 k = 0; k < _l; k++) {
                if (_tenureScore != tenureGroups[k]) continue;

                tenureGroups[k] = tenureGroups[_l - 1];
                tenureGroups.pop();
                delete isTenureGroupExist[_tenureScore];

                break;
            }
        }
        // END clear rebel group info

        _creatureContract.safeTransferFrom(address(this), msg.sender, _num);

        return _tenureScore;
    }

    /// @dev Decimals for number.
    function _getDecimals() internal pure returns (uint256) {
        return 10**27;
    }
}