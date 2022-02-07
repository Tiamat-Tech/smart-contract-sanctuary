// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {StructureData} from "./libraries/StructureData.sol";
import {Utils} from "./libraries/Utils.sol";
import {OptionLifecycle} from "./libraries/OptionLifecycle.sol";
import "./interfaces/IPKKTStructureOption.sol";
import "./OptionVault.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PKKTHodlBoosterOption is OptionVault, IPKKTStructureOption {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeMath for uint256;
    using Utils for uint256;
    using OptionLifecycle for StructureData.UserState;

    bool public canDepositEthAndUsdc;
    bool public canDepositWbtcAndUsdc;

    modifier canDeposit(uint8 _optionId) {
        if (_optionId == 1 || _optionId == 2) {
            require(canDepositEthAndUsdc, "cannot deposit eth or usdc");
        }
        if (_optionId == 3 || _optionId == 4) {
            require(canDepositWbtcAndUsdc, "cannot deposit wbtc or usdc");
        }
        _;
    }

    //private data for complete withdrawal and redeposit

    //take if for eth, we make price precision as 4, then underlying price can be 40000000 for 4000$
    //for shib, we make price precision as 8, then underlying price can be 4000 for 0.00004000$
    constructor(
        address _settler,
        StructureData.OptionPairDefinition[] memory _optionPairDefinitions
    ) OptionVault(_settler) {
        addOptionPairs(_optionPairDefinitions);
        canDepositEthAndUsdc = true;
        canDepositWbtcAndUsdc = true;
    }

    function validateOptionById(uint8 _optionId) private view {
        require(_optionId != 0 && _optionId <= optionPairCount * 2);
    }

    function getAccountBalance(uint8 _optionId)
        external
        view
        override
        returns (StructureData.UserBalance memory)
    {
        return
            OptionLifecycle.getAccountBalance(
                optionData[_optionId],
                msg.sender,
                underSettlement,
                currentRound
            );
    }

    function getOptionSnapShot(uint8 _optionId)
        external
        view
        override
        returns (StructureData.OptionSnapshot memory)
    {
        return
            OptionLifecycle.getOptionSnapShot(
                optionData[_optionId],
                underSettlement,
                currentRound
            );
    }

    function initiateWithraw(uint8 _optionId, uint256 _assetToTerminate)
        external
        override
    {
        //require(_assetToTerminate > 0 , "!_assetToTerminate");
        //require(currentRound > 1, "No on going");
        validateOptionById(_optionId);
        OptionLifecycle.initiateWithrawStorage(
            optionData[_optionId],
            msg.sender,
            _assetToTerminate,
            underSettlement,
            currentRound
        );
    }

    function cancelWithdraw(uint8 _optionId, uint256 _assetToTerminate)
        external
        override
    {
        //require(_assetToTerminate > 0 , "!_assetToTerminate");
        //require(currentRound > 1, "No on going");
        validateOptionById(_optionId);

        OptionLifecycle.cancelWithdrawStorage(
            optionData[_optionId],
            msg.sender,
            _assetToTerminate,
            underSettlement,
            currentRound
        );
    }

    function withdraw(
        uint8 _optionId,
        uint256 _amount,
        address _asset
    ) external override {
        //require(_amount > 0, "!amount");

        validateOptionById(_optionId);
        StructureData.OptionPairDefinition storage pair = optionPairs[
            (_optionId - 1) / 2
        ];
        //require(_asset == pair.depositAsset || _asset == pair.counterPartyAsset, "!asset");
        OptionLifecycle.withdrawStorage(
            optionData[_optionId],
            msg.sender,
            _amount,
            currentRound,
            (_optionId == pair.callOptionId && _asset == pair.depositAsset) ||
            (_optionId == pair.putOptionId && _asset == pair.counterPartyAsset)
        );
        clientWithdraw(msg.sender, _amount, _asset, false);
        emit Withdraw(_optionId, msg.sender, _asset, _amount);
    }

    //deposit eth
    function depositETH(uint8 _optionId) external payable override canDeposit(_optionId) {
        require(currentRound > 0, "!Started");
        require(msg.value > 0, "no value");

        validateOptionById(_optionId);
        StructureData.OptionPairDefinition storage pair = optionPairs[
            (_optionId - 1) / 2
        ];
        address depositAsset = pair.callOptionId == _optionId
            ? pair.depositAsset
            : pair.counterPartyAsset;
        require(depositAsset == address(0));

        //todo: convert to weth
        OptionLifecycle.depositFor(
            optionData[_optionId],
            msg.sender,
            msg.value,
            0,
            currentRound,
            true
        );

        emit Deposit(_optionId, msg.sender, currentRound, msg.value);
        //payable(vaultAddress()).transfer(msg.value);
    }

    //deposit other erc20 coin, take wbtc
    function deposit(uint8 _optionId, uint256 _amount) external override canDeposit(_optionId) {
        require(currentRound > 0, "!Started");
        require(_amount > 0, "!amount");
        validateOptionById(_optionId);
        StructureData.OptionPairDefinition storage pair = optionPairs[
            (_optionId - 1) / 2
        ];
        address depositAsset = pair.callOptionId == _optionId
            ? pair.depositAsset
            : pair.counterPartyAsset;
        require(depositAsset != address(0));

        OptionLifecycle.depositFor(
            optionData[_optionId],
            msg.sender,
            _amount,
            0,
            currentRound,
            true
        );
        emit Deposit(_optionId, msg.sender, currentRound, _amount);
        IERC20(depositAsset).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
    }

    // Switches allowing deposits for the given option pait on/off
    function switchOptionPair(uint8 pairId) external settlerOnly {
        // ETH-USDC pair
        if(pairId == 0) {
            canDepositEthAndUsdc = !canDepositEthAndUsdc;
        }
        // WBTC-USDC pair
        else if (pairId == 1) {
            canDepositWbtcAndUsdc = !canDepositWbtcAndUsdc;
        }
    }

    //used to render the history at client side, reading the minting transactions of a specific address,
    //for each transaction, read the blockheight and call this method to get the result
    //the blockheight is the the height when the round is committed
    //function getRoundData(uint8 _optionId, uint256 _blockHeight) external view override returns(StructureData.OptionState memory) {
    //    return optionStates[_optionId][optionHeights[_blockHeight]];
    //}

    /*function getRoundDataByBlock(uint8 _optionId, uint256 _blockHeight) external view override returns(StructureData.OptionState memory) {
        return optionData[_optionId].optionStates[optionHeights[_blockHeight]];
    }*/

    function getOptionStateByRound(uint8 _optionId, uint16 _round)
        external
        view
        override
        returns (StructureData.OptionState memory)
    {
        return optionData[_optionId].optionStates[_round];
    }

    function autoRollToCounterPartyByOption(
        StructureData.OptionData storage _option,
        StructureData.OptionState storage _optionState,
        StructureData.OptionData storage _counterPartyOption,
        uint8 _counterPartyOptionId,
        uint256 _totalReleased,
        uint256 _totalAutoRoll
    ) internal override {
        uint256 totalAutoRollBase = uint256(_optionState.totalAmount).sub(
            _optionState.totalTerminate
        );
        if (_option.assetToTerminateForNextRound > 0 && _totalAutoRoll > 0) {
            _option.assetToTerminateForNextRound = uint256(_option
                .assetToTerminateForNextRound)
                .subOrZero(
                    totalAutoRollBase.withPremium(_optionState.premiumRate)
                ).toUint128();
        }
        uint256 userCount = _option.usersInvolved.length;
        for (uint256 i = 0; i < userCount; i++) {
            address userAddress = _option.usersInvolved[i];
            StructureData.UserState storage userState = _option.userStates[
                userAddress
            ];

            if (userState.ongoingAsset == 0) {
                continue;
            }
            uint256 amountToTerminate = Utils.getAmountToTerminate(
                _totalReleased,
                userState.assetToTerminate,
                _optionState.totalTerminate
            );
            if (amountToTerminate > 0) {
                userState.releasedCounterPartyAssetAmount = uint256(userState
                    .releasedCounterPartyAssetAmount)
                    .add(amountToTerminate).toUint128();
            }
            uint256 onGoing = uint256(userState.ongoingAsset).sub(
                userState.assetToTerminate
            );
            uint256 remainingAmount = Utils.getAmountToTerminate(
                _totalAutoRoll,
                onGoing,
                totalAutoRollBase
            );
            if (remainingAmount > 0) {
                uint256 onGoingTerminate = 0;
                uint256 virtualOnGoing = onGoing.withPremium(
                    _optionState.premiumRate
                );
                if (userState.assetToTerminateForNextRound <= virtualOnGoing) {
                    onGoingTerminate = Utils.getAmountToTerminate(
                        remainingAmount,
                        userState.assetToTerminateForNextRound,
                        virtualOnGoing
                    );
                } else {
                    onGoingTerminate = remainingAmount;
                }
                OptionLifecycle.depositFor(
                    _counterPartyOption,
                    userAddress,
                    remainingAmount,
                    onGoingTerminate,
                    currentRound - 1,
                    false
                );
                emit Deposit(
                    _counterPartyOptionId,
                    userAddress,
                    currentRound - 1,
                    remainingAmount
                );
            }
            userState.assetToTerminate = 0;
        }
    }

    function autoRollByOption(
        StructureData.OptionData storage _option,
        uint8 _optionId,
        StructureData.OptionState storage _optionState,
        uint256 _totalReleased,
        uint256 _totalAutoRoll
    ) internal override {
        //uint256 lockedRound = currentRound - 1;

        uint256 totalAutoRollBase = uint256(_optionState.totalAmount).sub(
            _optionState.totalTerminate
        );
        uint256 userCount = _option.usersInvolved.length;
        for (uint256 i = 0; i < userCount; i++) {
            address userAddress = _option.usersInvolved[i];
            StructureData.UserState storage userState = _option.userStates[
                userAddress
            ];
            if (userState.ongoingAsset == 0) {
                continue;
            }

            uint256 amountToTerminate = Utils.getAmountToTerminate(
                _totalReleased,
                userState.assetToTerminate,
                _optionState.totalTerminate
            );
            if (amountToTerminate > 0) {
                userState.releasedDepositAssetAmount = uint256(userState
                    .releasedDepositAssetAmount)
                    .add(amountToTerminate).toUint128();
            }
            uint256 remainingAmount = Utils.getAmountToTerminate(
                _totalAutoRoll,
                uint256(userState.ongoingAsset).sub(userState.assetToTerminate),
                totalAutoRollBase
            );
            if (remainingAmount > 0) {
                OptionLifecycle.depositFor(
                    _option,
                    userAddress,
                    remainingAmount,
                    0,
                    currentRound - 1,
                    false
                );
                emit Deposit(
                    _optionId,
                    userAddress,
                    currentRound - 1,
                    remainingAmount
                );
            }

            userState.assetToTerminate = 0;
        }
    }
}