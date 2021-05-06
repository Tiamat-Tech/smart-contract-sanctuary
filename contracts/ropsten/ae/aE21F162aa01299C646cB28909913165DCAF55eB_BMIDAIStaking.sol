// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/EnumerableMap.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

import "./interfaces/tokens/erc20permit-upgradeable/IERC20PermitUpgradeable.sol";

import "./interfaces/IPolicyBookRegistry.sol";
import "./interfaces/IBMIDAIStaking.sol";
import "./interfaces/IContractsRegistry.sol";
import "./interfaces/IRewardsGenerator.sol";
import "./interfaces/ILiquidityMining.sol";
import "./interfaces/IPolicyBook.sol";
import "./interfaces/IBMIStaking.sol";
import "./interfaces/ILiquidityRegistry.sol";

import "./abstract/AbstractDependant.sol";
import "./abstract/AbstractSlasher.sol";

import "./Globals.sol";

contract BMIDAIStaking is
    IBMIDAIStaking,
    OwnableUpgradeable,
    ERC1155Upgradeable,
    AbstractDependant,
    AbstractSlasher
{
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using SafeMath for uint256;
    using Math for uint256;

    uint256 internal constant THREE_MONTH = 3 * ONE_MONTH;

    IERC20 public daiToken;
    IERC20 public bmiToken;
    IPolicyBookRegistry public policyBookRegistry;
    IRewardsGenerator public rewardsGenerator;
    ILiquidityMining public liquidityMining;
    IBMIStaking public bmiStaking;
    ILiquidityRegistry public liquidityRegistry;

    mapping(uint256 => StakingInfo) internal _stakersPool; // nft index -> info
    uint256 internal _nftMintId; // next nft mint id

    mapping(address => EnumerableSet.UintSet) internal _nftHolderTokens; // holder -> nfts
    EnumerableMap.UintToAddressMap internal _nftTokenOwners; // index nft -> holder

    event StakingNFTMinted(uint256 id, address policyBookAddress, address to);
    event StakingNFTBurned(uint256 id, address policyBookAddress);
    event StakingBMIProfitWithdrawn(
        uint256 id,
        address policyBookAddress,
        address to,
        uint256 amount
    );
    event StakingFundsWithdrawn(uint256 id, address policyBookAddress, address to);

    modifier onlyPolicyBooks() {
        require(
            policyBookRegistry.isPolicyBook(_msgSender()),
            "BMIDAIStaking: The caller does not have access"
        );
        _;
    }

    function __BMIDAIStaking_init() external initializer {
        __Ownable_init();
        __ERC1155_init("");

        _nftMintId = 1;
    }

    function setDependencies(IContractsRegistry _contractsRegistry)
        external
        override
        onlyInjectorOrZero
    {
        daiToken = IERC20(_contractsRegistry.getDAIContract());
        bmiToken = IERC20(_contractsRegistry.getBMIContract());
        rewardsGenerator = IRewardsGenerator(_contractsRegistry.getRewardsGeneratorContract());
        policyBookRegistry = IPolicyBookRegistry(
            _contractsRegistry.getPolicyBookRegistryContract()
        );
        liquidityMining = ILiquidityMining(_contractsRegistry.getLiquidityMiningContract());
        bmiStaking = IBMIStaking(_contractsRegistry.getBMIStakingContract());
        liquidityRegistry = ILiquidityRegistry(_contractsRegistry.getLiquidityRegistryContract());
    }

    /// @dev this is a correct URI: "https://token-cdn-domain/\{id\}.json"
    function setURI(string calldata newURI) external onlyOwner {
        _setURI(newURI);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        for (uint256 i = 0; i < ids.length; i++) {
            if (amounts[i] != 1) {
                // not an NFT
                continue;
            }

            if (from == address(0)) {
                // mint happened
                _nftHolderTokens[to].add(ids[i]);
                _nftTokenOwners.set(ids[i], to);
            } else if (to == address(0)) {
                // burn happened
                _nftHolderTokens[from].remove(ids[i]);
                _nftTokenOwners.remove(ids[i]);
            } else {
                // transfer happened
                _nftHolderTokens[from].remove(ids[i]);
                _nftHolderTokens[to].add(ids[i]);

                _nftTokenOwners.set(ids[i], to);

                _updateLiquidityRegistry(to, from, _stakersPool[ids[i]].policyBookAddress);
            }
        }
    }

    function _updateLiquidityRegistry(
        address to,
        address from,
        address policyBookAddress
    ) internal {
        liquidityRegistry.tryToAddPolicyBook(to, policyBookAddress);
        liquidityRegistry.tryToRemovePolicyBook(from, policyBookAddress);
    }

    function _mintStake(address staker, uint256 id) internal {
        _mint(staker, id, 1, ""); // mint NFT
    }

    function _burnStake(address staker, uint256 id) internal {
        _burn(staker, id, 1); // burn NFT
    }

    function _mintAggregatedNFT(
        address staker,
        address policyBookAddress,
        uint256[] memory tokenIds
    ) internal {
        uint256 totalDaiAmount;
        uint256 totalBmiDaiAmount;
        uint256 suggestedDuration;
        uint256 _currentId;

        uint256[] memory stakedDAI = new uint256[](tokenIds.length);

        /// @notice impossible to make user's total amount storage variable because ownership of
        /// NFTs may change and we wouldn't know how much stake does a staker have
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _currentId = tokenIds[i];

            require(ownerOf(_currentId) == _msgSender(), "BMIDAIStaking: Not an NFT token owner");

            stakedDAI[i] = rewardsGenerator.getDAIStake(_currentId);

            totalDaiAmount = totalDaiAmount.add(stakedDAI[i]);
            totalBmiDaiAmount = totalBmiDaiAmount.add(_stakersPool[_currentId].stakedBmiDaiAmount);
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _currentId = tokenIds[i];
            uint256 ratio = stakedDAI[i].mul(PERCENTAGE_100).div(totalDaiAmount);
            uint256 stakingEndTime = _stakersPool[_currentId].stakingEndTime;
            uint256 timeLeft =
                block.timestamp >= stakingEndTime ? 0 : stakingEndTime.sub(block.timestamp);

            suggestedDuration = suggestedDuration.add(timeLeft.mul(ratio).div(PERCENTAGE_100));

            _burnStake(staker, _currentId);

            emit StakingNFTBurned(_currentId, policyBookAddress);

            /// @dev should be enough
            delete _stakersPool[_currentId].policyBookAddress;
            delete _stakersPool[_currentId].stakingEndTime;
        }

        _mintStake(staker, _nftMintId);

        _stakersPool[_nftMintId] = StakingInfo(
            policyBookAddress,
            block.timestamp,
            block.timestamp.add(suggestedDuration),
            totalBmiDaiAmount
        );

        emit StakingNFTMinted(_nftMintId, policyBookAddress, staker);

        _nftMintId++;
    }

    function _mintNewNFT(
        address staker,
        uint256 bmiDaiAmount,
        address policyBookAddress
    ) internal {
        _mintStake(staker, _nftMintId);

        _stakersPool[_nftMintId] = StakingInfo(
            policyBookAddress,
            block.timestamp,
            block.timestamp.add(THREE_MONTH),
            bmiDaiAmount
        );

        emit StakingNFTMinted(_nftMintId, policyBookAddress, staker);

        _nftMintId++;
    }

    function aggregateNFTs(address policyBookAddress, uint256[] calldata tokenIds)
        external
        override
    {
        require(tokenIds.length > 1, "BMIDAIStaking: Can't aggregate a single token");

        _mintAggregatedNFT(_msgSender(), policyBookAddress, tokenIds);
        rewardsGenerator.aggregate(policyBookAddress, tokenIds, _nftMintId - 1); // nftMintId is changed, so -1
    }

    function stakeDAIx(uint256 bmiDaiAmount, address policyBookAddress) external override {
        _stakeDAIx(_msgSender(), bmiDaiAmount, policyBookAddress);
    }

    function stakeDAIxWithPermit(
        uint256 bmiDaiAmount,
        address policyBookAddress,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        _stakeDAIxWithPermit(_msgSender(), bmiDaiAmount, policyBookAddress, v, r, s);
    }

    function stakeDAIxFrom(address user, uint256 bmiDaiAmount) external override onlyPolicyBooks {
        _stakeDAIx(user, bmiDaiAmount, _msgSender());
    }

    function stakeDAIxFromWithPermit(
        address user,
        uint256 bmiDaiAmount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override onlyPolicyBooks {
        _stakeDAIxWithPermit(user, bmiDaiAmount, _msgSender(), v, r, s);
    }

    function _stakeDAIxWithPermit(
        address staker,
        uint256 bmiDaiAmount,
        address policyBookAddress,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        IERC20PermitUpgradeable(policyBookAddress).permit(
            staker,
            address(this),
            bmiDaiAmount,
            MAX_INT,
            v,
            r,
            s
        );

        _stakeDAIx(staker, bmiDaiAmount, policyBookAddress);
    }

    function _stakeDAIx(
        address user,
        uint256 bmiDaiAmount,
        address policyBookAddress
    ) internal {
        require(
            policyBookRegistry.isPolicyBook(policyBookAddress),
            "BMIDAIStaking: The address is not a PolicyBook"
        );
        require(
            IPolicyBook(policyBookAddress).whitelisted(),
            "BMIDAIStaking: PB is not whitelisted"
        );
        require(bmiDaiAmount > 0, "BMIDAIStaking: Can't stake zero tokens");

        uint256 daiAmount = IPolicyBook(policyBookAddress).convertDAIXToDAI(bmiDaiAmount);

        // transfer bmiDAIx from user to staking
        IERC20(policyBookAddress).transferFrom(user, address(this), bmiDaiAmount);

        _mintNewNFT(user, bmiDaiAmount, policyBookAddress);
        rewardsGenerator.stake(policyBookAddress, _nftMintId - 1, daiAmount); // nftMintId is changed, so -1
    }

    function _transferProfit(uint256 tokenId, bool onlyProfit) internal {
        address policyBookAddress = _stakersPool[tokenId].policyBookAddress;
        uint256 totalProfit;

        if (onlyProfit) {
            totalProfit = rewardsGenerator.withdrawReward(policyBookAddress, tokenId);
        } else {
            totalProfit = rewardsGenerator.withdrawFunds(policyBookAddress, tokenId);
        }

        uint256 bmiStakingProfit =
            totalProfit.mul(getSlashingPercentage(liquidityMining.startLiquidityMiningTime())).div(
                PERCENTAGE_100
            );
        uint256 profit = totalProfit.sub(bmiStakingProfit);

        // transfer slashed bmi to the bmiStaking and add them to the pool
        bmiToken.transfer(address(bmiStaking), bmiStakingProfit);
        bmiStaking.addToPool(bmiStakingProfit);

        // transfer bmi profit to the user
        bmiToken.transfer(_msgSender(), profit);

        emit StakingBMIProfitWithdrawn(tokenId, policyBookAddress, _msgSender(), profit);
    }

    function getPolicyBookAPY(address policyBookAddress) external view override returns (uint256) {
        return
            IPolicyBook(policyBookAddress).whitelisted()
                ? rewardsGenerator.getPolicyBookAPY(policyBookAddress)
                : 0;
    }

    function getBMIProfit(uint256 tokenId) public view override returns (uint256) {
        uint256 totalProfit =
            rewardsGenerator.getReward(_stakersPool[tokenId].policyBookAddress, tokenId);

        return
            totalProfit.sub(
                totalProfit
                    .mul(getSlashingPercentage(liquidityMining.startLiquidityMiningTime()))
                    .div(PERCENTAGE_100)
            );
    }

    function getStakerBMIProfit(
        address staker,
        address policyBookAddress,
        uint256 offset,
        uint256 limit
    ) external view override returns (uint256 totalProfit) {
        uint256 to = (offset.add(limit)).min(balanceOf(staker)).max(offset);

        for (uint256 i = offset; i < to; i++) {
            uint256 nftIndex = tokenOfOwnerByIndex(staker, i);

            if (_stakersPool[nftIndex].policyBookAddress == policyBookAddress) {
                totalProfit = totalProfit.add(getBMIProfit(nftIndex));
            }
        }
    }

    function _forEachToken(
        address policyBookAddress,
        bool includeLocked,
        function(uint256) func
    ) internal {
        require(
            policyBookRegistry.isPolicyBook(policyBookAddress),
            "BMIDAIStaking: Not a policybook"
        );

        uint256 stakerBalance = balanceOf(_msgSender());

        for (int256 i = int256(stakerBalance) - 1; i >= 0; i--) {
            uint256 nftIndex = tokenOfOwnerByIndex(_msgSender(), uint256(i));

            if (
                _stakersPool[nftIndex].policyBookAddress == policyBookAddress &&
                (includeLocked || block.timestamp > _stakersPool[nftIndex].stakingEndTime)
            ) {
                func(nftIndex);
            }
        }
    }

    function restakeBMIProfit(uint256 tokenId) public override {
        require(
            _stakersPool[tokenId].stakingEndTime != 0,
            "BMIDAIStaking: This staking token doesn't exist"
        );
        require(ownerOf(tokenId) == _msgSender(), "BMIDAIStaking: Not an NFT token owner");

        uint256 totalProfit =
            rewardsGenerator.withdrawReward(_stakersPool[tokenId].policyBookAddress, tokenId);

        bmiToken.transfer(address(bmiStaking), totalProfit);
        bmiStaking.stakeFor(_msgSender(), totalProfit);
    }

    function restakeStakerBMIProfit(address policyBookAddress) external override {
        _forEachToken(policyBookAddress, true, restakeBMIProfit);
    }

    function withdrawBMIProfit(uint256 tokenId) public override {
        require(
            _stakersPool[tokenId].stakingEndTime != 0,
            "BMIDAIStaking: This staking token doesn't exist"
        );
        require(ownerOf(tokenId) == _msgSender(), "BMIDAIStaking: Not an NFT token owner");

        _transferProfit(tokenId, true);
    }

    function withdrawStakerBMIProfit(address policyBookAddress) external override {
        _forEachToken(policyBookAddress, true, withdrawBMIProfit);
    }

    function withdrawFundsWithProfit(uint256 tokenId) public override {
        StakingInfo storage stakingInfo = _stakersPool[tokenId];

        require(
            stakingInfo.stakingEndTime != 0,
            "BMIDAIStaking: This staking token doesn't exist"
        );
        require(block.timestamp > stakingInfo.stakingEndTime, "BMIDAIStaking: Funds are locked");
        require(ownerOf(tokenId) == _msgSender(), "BMIDAIStaking: Not an NFT token owner");

        _transferProfit(tokenId, false);

        address policyBookAddress = stakingInfo.policyBookAddress;

        // transfer bmiDAIx from staking to the user
        IERC20(policyBookAddress).transfer(_msgSender(), stakingInfo.stakedBmiDaiAmount);

        emit StakingFundsWithdrawn(tokenId, policyBookAddress, _msgSender());

        _burnStake(_msgSender(), tokenId);

        emit StakingNFTBurned(tokenId, policyBookAddress);

        delete _stakersPool[tokenId];
    }

    function withdrawStakerFundsWithProfit(address policyBookAddress) external override {
        _forEachToken(policyBookAddress, false, withdrawFundsWithProfit);
    }

    function stakingInfoByToken(uint256 tokenId)
        external
        view
        override
        returns (StakingInfo memory)
    {
        require(
            _stakersPool[tokenId].stakingEndTime != 0,
            "BMIDAIStaking: This staking token doesn't exist"
        );

        return _stakersPool[tokenId];
    }

    /// @dev offset and limit is taken in regards of NFTs on account
    function stakingInfoByStaker(
        address staker,
        address[] calldata policyBooksAddresses,
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (
            string memory URI,
            uint256[] memory nftsCount,
            NFTsInfo[][] memory nftsInfo
        )
    {
        uint256 to = (offset.add(limit)).min(balanceOf(staker)).max(offset);

        URI = this.uri(0);
        nftsCount = new uint256[](policyBooksAddresses.length);
        nftsInfo = new NFTsInfo[][](policyBooksAddresses.length);

        for (uint256 i = 0; i < policyBooksAddresses.length; i++) {
            nftsInfo[i] = new NFTsInfo[](to - offset);

            for (uint256 j = offset; j < to; j++) {
                uint256 nftIndex = tokenOfOwnerByIndex(staker, j);

                if (_stakersPool[nftIndex].policyBookAddress == policyBooksAddresses[i]) {
                    StakingInfo storage info = _stakersPool[nftIndex];

                    nftsInfo[i][nftsCount[i]] = NFTsInfo(
                        nftIndex,
                        info.stakingStartTime,
                        info.stakingEndTime,
                        info.stakedBmiDaiAmount,
                        getBMIProfit(nftIndex)
                    );

                    nftsCount[i]++;
                }
            }
        }
    }

    function _totalStaked(
        address user,
        address policyBookAddress,
        bool check
    ) internal view returns (uint256) {
        uint256 stakerBalance = balanceOf(user);
        uint256 totalAmount;

        for (uint256 i = 0; i < stakerBalance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(user, i);

            if (!check || policyBookAddress == _stakersPool[tokenId].policyBookAddress) {
                totalAmount = totalAmount.add(_stakersPool[tokenId].stakedBmiDaiAmount);
            }
        }

        return totalAmount;
    }

    function totalStaked(address user, address policyBookAddress)
        external
        view
        override
        returns (uint256)
    {
        return _totalStaked(user, policyBookAddress, true);
    }

    function totalStaked(address user) external view override returns (uint256) {
        return _totalStaked(user, address(0), false);
    }

    function balanceOf(address user) public view override returns (uint256) {
        return _nftHolderTokens[user].length();
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _nftTokenOwners.get(tokenId);
    }

    function tokenOfOwnerByIndex(address user, uint256 index)
        public
        view
        override
        returns (uint256)
    {
        return _nftHolderTokens[user].at(index);
    }
}