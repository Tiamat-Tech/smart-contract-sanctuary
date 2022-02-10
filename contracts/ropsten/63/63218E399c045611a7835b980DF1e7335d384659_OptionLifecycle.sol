// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Utils.sol";
import "./StructureData.sol";
//import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

library OptionLifecycle {
    using SafeERC20 for IERC20;
    using Utils for uint128;
    using Utils for uint256;
    using SafeMath for uint256;
    using SafeCast for uint256;
    using StructureData for StructureData.UserState;

    function deriveVirtualLocked(
        StructureData.UserState memory userState,
        uint16 premiumRate
    ) internal pure returns (uint256) {
        uint256 onGoing = uint256(userState.ongoingAsset);
        if (onGoing == 0) {
            return uint256(userState.tempLocked);
        }
        onGoing = (onGoing.sub(userState.assetToTerminate)).withPremium(
            premiumRate
        );
        if (userState.tempLocked == 0) {
            return onGoing;
        }
        return uint256(userState.tempLocked).add(onGoing);
    }

    function getAvailableBalance(address _asset, address _source)
        external
        view
        returns (uint256)
    {
        if (_asset != address(0)) {
            return IERC20(_asset).balanceOf(_source);
        } else {
            return _source.balance;
        }
    }

    function withdraw(
        address _target,
        uint256 _amount,
        address _contractAddress
    ) external {
        require(_amount > 0);
        if (_contractAddress == address(0)) {
            payable(_target).transfer(_amount);
        } else {
            IERC20(_contractAddress).safeTransfer(_target, _amount);
        }
    }

    function calculateMaturity(
        bool _execute,
        StructureData.OptionState memory _optionState,
        bool _callOrPut,
        uint8 _depositAssetAmountDecimals,
        uint8 _counterPartyAssetAmountDecimals
    ) public pure returns (StructureData.MaturedState memory) {
        StructureData.MaturedState memory state = StructureData.MaturedState({
            releasedDepositAssetAmount: 0,
            releasedDepositAssetPremiumAmount: 0,
            releasedDepositAssetAmountWithPremium: 0,
            autoRollDepositAssetAmount: 0,
            autoRollDepositAssetPremiumAmount: 0,
            autoRollDepositAssetAmountWithPremium: 0,
            releasedCounterPartyAssetAmount: 0,
            releasedCounterPartyAssetPremiumAmount: 0,
            releasedCounterPartyAssetAmountWithPremium: 0,
            autoRollCounterPartyAssetAmount: 0,
            autoRollCounterPartyAssetPremiumAmount: 0,
            autoRollCounterPartyAssetAmountWithPremium: 0
        });
        if (_execute) {
            uint256 maturedCounterPartyAssetAmount = 
                _callOrPut
                    ? uint256(_optionState.totalAmount)
                        .mul(_optionState.strikePrice)
                        .mul(10**_counterPartyAssetAmountDecimals)
                        .div(
                            10 **
                                (StructureData.PRICE_PRECISION +
                                    _depositAssetAmountDecimals)
                        )
                    : uint256(_optionState.totalAmount)
                        .mul(
                            10 **
                                (StructureData.PRICE_PRECISION +
                                    _counterPartyAssetAmountDecimals)
                        )
                        .div(_optionState.strikePrice)
                        .div(10**_depositAssetAmountDecimals);

            uint256 maturedCounterPartyAssetPremiumAmount = maturedCounterPartyAssetAmount
                    .premium(_optionState.premiumRate);
            if (_optionState.totalTerminate > 0) {
                state
                    .releasedCounterPartyAssetAmount = maturedCounterPartyAssetAmount
                    .getAmountToTerminate(
                        _optionState.totalTerminate,
                        _optionState.totalAmount
                    );
                state
                    .releasedCounterPartyAssetPremiumAmount = maturedCounterPartyAssetPremiumAmount
                    .getAmountToTerminate(
                        _optionState.totalTerminate,
                        _optionState.totalAmount
                    );
                state.releasedCounterPartyAssetAmountWithPremium =
                    state.releasedCounterPartyAssetAmount.add(
                    state.releasedCounterPartyAssetPremiumAmount);
            }
            state.autoRollCounterPartyAssetAmount =
                maturedCounterPartyAssetAmount.sub(
                state.releasedCounterPartyAssetAmount);
            state.autoRollCounterPartyAssetPremiumAmount =
                maturedCounterPartyAssetPremiumAmount.sub(
                state.releasedCounterPartyAssetPremiumAmount);
            state.autoRollCounterPartyAssetAmountWithPremium =
                state.autoRollCounterPartyAssetAmount.add(
                state.autoRollCounterPartyAssetPremiumAmount);
        } else {
            uint256 maturedDepositAssetAmount = uint256(_optionState.totalAmount);
            uint256 maturedDepositAssetPremiumAmount = maturedDepositAssetAmount
                .premium(_optionState.premiumRate);
            if (_optionState.totalTerminate > 0) {
                state.releasedDepositAssetAmount = maturedDepositAssetAmount
                    .getAmountToTerminate(
                        _optionState.totalTerminate,
                        _optionState.totalAmount
                    );
                state
                    .releasedDepositAssetPremiumAmount = maturedDepositAssetPremiumAmount
                    .getAmountToTerminate(
                        _optionState.totalTerminate,
                        _optionState.totalAmount
                    );
                state.releasedDepositAssetAmountWithPremium =
                    state.releasedDepositAssetAmount.add(
                    state.releasedDepositAssetPremiumAmount);
            }
            state.autoRollDepositAssetAmount =
                maturedDepositAssetAmount.sub(
                state.releasedDepositAssetAmount);
            state.autoRollDepositAssetPremiumAmount =
                maturedDepositAssetPremiumAmount.sub(
                state.releasedDepositAssetPremiumAmount);
            state.autoRollDepositAssetAmountWithPremium =
                state.autoRollDepositAssetAmount.add(
                state.autoRollDepositAssetPremiumAmount);
        }
        return state;
    }

    function commitByOption(
        StructureData.OptionData storage _option,
        uint16 _roundToCommit
    ) external {
        uint256 userCount = _option.usersInvolved.length;
        for (uint256 i = 0; i < userCount; i++) {
            StructureData.UserState storage userState = _option.userStates[
                _option.usersInvolved[i]
            ];
            if (userState.assetToTerminateForNextRound != 0) {
                userState.assetToTerminate = userState
                    .assetToTerminateForNextRound;
                userState.assetToTerminateForNextRound = 0;
            } else if (userState.assetToTerminate != 0) {
                userState.assetToTerminate = 0;
            }
            if (userState.tempLocked == 0) {
                userState.ongoingAsset = 0;
                continue;
            }
            userState.ongoingAsset = userState.tempLocked;
            userState.tempLocked = 0;
        } 
        _option.optionStates[_roundToCommit].totalTerminate = uint256(_option
            .optionStates[_roundToCommit]
            .totalTerminate)
            .add(_option.assetToTerminateForNextRound).toUint128();
        _option.assetToTerminateForNextRound = 0;
    }

    function rollToNextByOption(
        StructureData.OptionData storage _option,
        uint16 _currentRound,
        bool _callOrPut
    ) external returns (uint128 _pendingAmount) { 
        StructureData.OptionState memory currentOption = StructureData
            .OptionState({
                round: _currentRound,
                totalAmount: 0,
                totalTerminate: 0,
                premiumRate: 0,
                strikePrice: 0,
                executed: false,
                callOrPut: _callOrPut
            });
        _option.optionStates[_currentRound] = currentOption;
        if (_currentRound > 1) {
            uint256 userCount = _option.usersInvolved.length;
            for (uint256 i = 0; i < userCount; i++) {
                StructureData.UserState storage userState = _option.userStates[
                    _option.usersInvolved[i]
                ];
                if (userState.pendingAsset != 0) {
                    userState.tempLocked = userState.pendingAsset;
                }
                userState.pendingAsset = 0;
            }
        } 
        return
            _currentRound > 1
                ? _option.optionStates[_currentRound - 1].totalAmount
                : 0;
    }

    function dryRunSettlementByOption(
        StructureData.OptionData storage _option,
        bool _isCall,
        uint8 _depositAssetAmountDecimals,
        uint8 _counterPartyAssetAmountDecimals,
        uint16 _currentRound,
        bool _execute
    )
        external
        view
        returns (StructureData.SettlementAccountingResult memory _result)
    {
        StructureData.SettlementAccountingResult memory result = StructureData
            .SettlementAccountingResult({ 
                depositAmount: _option
                    .optionStates[_currentRound - 1]
                    .totalAmount,
                executed: _execute,
                autoRollAmount: 0,
                autoRollPremium: 0,
                releasedAmount: 0,
                releasedPremium: 0,
                autoRollCounterPartyAmount: 0,
                autoRollCounterPartyPremium: 0,
                releasedCounterPartyAmount: 0,
                releasedCounterPartyPremium: 0
            });
        if (_currentRound > 2) {
            StructureData.OptionState storage previousOptionState = _option
                .optionStates[_currentRound - 2];
            if (previousOptionState.totalAmount == 0) {
                return result;
            }
            StructureData.MaturedState memory maturedState = calculateMaturity(
                _execute,
                previousOptionState,
                _isCall,
                _depositAssetAmountDecimals,
                _counterPartyAssetAmountDecimals
            );
            if (_execute) {
                result.autoRollCounterPartyAmount = maturedState
                    .autoRollCounterPartyAssetAmount.toUint128();
                result.autoRollCounterPartyPremium = maturedState
                    .autoRollCounterPartyAssetPremiumAmount.toUint128();
                result.releasedCounterPartyAmount = maturedState
                    .releasedCounterPartyAssetAmount.toUint128();
                result.releasedCounterPartyPremium = maturedState
                    .releasedCounterPartyAssetPremiumAmount.toUint128();
            } else {
                result.autoRollAmount = maturedState.autoRollDepositAssetAmount.toUint128();
                result.autoRollPremium = maturedState
                    .autoRollDepositAssetPremiumAmount.toUint128();
                result.releasedAmount = maturedState.releasedDepositAssetAmount.toUint128();
                result.releasedPremium = maturedState
                    .releasedDepositAssetPremiumAmount.toUint128();
            }
        }
        return result;
    }

    function closePreviousByOption(
        StructureData.OptionData storage _option,
        StructureData.OptionState storage previousOptionState,
        bool _isCall,
        uint8 _depositAssetAmountDecimals,
        uint8 _counterPartyAssetAmountDecimals,
        bool _execute
    ) external returns (StructureData.MaturedState memory _maturedState) {
        //uint16 maturedRound = currentRound - 2;
        StructureData.MaturedState memory maturedState = calculateMaturity(
            _execute,
            previousOptionState,
            _isCall,
            _depositAssetAmountDecimals,
            _counterPartyAssetAmountDecimals
        );
        previousOptionState.executed = _execute;

        if (_execute) {
            _option.totalReleasedCounterPartyAssetAmount =uint256(_option
                .totalReleasedCounterPartyAssetAmount)
                .add(maturedState.releasedCounterPartyAssetAmountWithPremium).toUint128();
        } else {
            _option.totalReleasedDepositAssetAmount = uint256(_option
                .totalReleasedDepositAssetAmount)
                .add(maturedState.releasedDepositAssetAmountWithPremium).toUint128();
        }
        return maturedState;
    }
    /*
        struct OptionParameters { 
        uint128 strikePrice; // strike price if executed
        uint16 premiumRate; //take, 0.01% is represented as 1, precision is 4
    }
*/
    function setOptionParameters(uint256 _parameters, StructureData.OptionState storage _optionState) external {
 
        require(_optionState.strikePrice == 0); 
        _optionState.strikePrice = uint128(_parameters >> 16);
        _optionState.premiumRate = uint16(_parameters & 0xffff);     
    }
    function getAccountBalance(
        StructureData.OptionData storage _option,
        address _user,
        bool _underSettlement,
        uint16 _currentRound
    ) external view returns (StructureData.UserBalance memory) {
        StructureData.UserState storage userState = _option.userStates[_user];

        StructureData.UserBalance memory result = StructureData.UserBalance({
            pendingDepositAssetAmount: userState.pendingAsset,
            releasedDepositAssetAmount: userState.releasedDepositAssetAmount,
            releasedCounterPartyAssetAmount: userState
                .releasedCounterPartyAssetAmount,
            lockedDepositAssetAmount: 0,
            terminatingDepositAssetAmount: 0,
            toTerminateDepositAssetAmount: 0
        });
        if (_underSettlement) {
            if (_currentRound > 2) {
                //when there are maturing round waiting for settlement, it becomes complex
                uint16 premiumRate = _option
                    .optionStates[_currentRound - 2]
                    .premiumRate;
                result.lockedDepositAssetAmount = deriveVirtualLocked(
                    userState,
                    premiumRate
                ).toUint128();
                result.terminatingDepositAssetAmount = uint256(userState
                    .assetToTerminate)
                    .withPremium(premiumRate).toUint128();
            } else {
                result.lockedDepositAssetAmount = userState.tempLocked;
            }
            result.toTerminateDepositAssetAmount = userState
                    .assetToTerminateForNextRound;
        } else {
            result.lockedDepositAssetAmount = userState.ongoingAsset;
            result.toTerminateDepositAssetAmount = userState.assetToTerminate;
        }
        return result;
    }

    function getOptionSnapShot(
        StructureData.OptionData storage _option,
        bool _underSettlement,
        uint16 _currentRound
    ) external view returns (StructureData.OptionSnapshot memory) {
        StructureData.OptionState memory lockedOption;
        StructureData.OptionState memory onGoingOption;
        StructureData.OptionSnapshot memory result = StructureData
            .OptionSnapshot({
                totalPending: _option.optionStates[_currentRound].totalAmount,
                totalReleasedDeposit: _option.totalReleasedDepositAssetAmount,
                totalReleasedCounterParty: _option
                    .totalReleasedCounterPartyAssetAmount,
                totalLocked: 0,
                totalTerminating: 0,
                totalToTerminate: 0
            });
        if (_underSettlement) {
            lockedOption = _option.optionStates[_currentRound - 1];
            result.totalToTerminate = _option.assetToTerminateForNextRound;
            if (_currentRound > 2) {
                //when there are maturing round waiting for settlement, it becomes complex
                onGoingOption = _option.optionStates[_currentRound - 2];
                result.totalTerminating = uint256(onGoingOption
                    .totalTerminate)
                    .withPremium(onGoingOption.premiumRate).toUint128();
                result.totalLocked = uint256(lockedOption
                    .totalAmount)
                    .add(
                        onGoingOption.totalAmount.withPremium(
                            onGoingOption.premiumRate
                        )
                    )
                    .sub(result.totalTerminating).toUint128();
            } else {
                result.totalLocked = lockedOption.totalAmount;
            }
        } else if (_currentRound > 1) {
            onGoingOption = _option.optionStates[_currentRound - 1];
            result.totalLocked = onGoingOption.totalAmount;
            result.totalToTerminate = onGoingOption.totalTerminate;
        }
        return result;
    }

    function initiateWithrawStorage(
        StructureData.OptionData storage _option,
        address _user,
        uint256 _assetToTerminate,
        bool _underSettlement,
        uint16 _currentRound
    ) external {
        StructureData.UserState storage userState = _option.userStates[_user];
        if (_underSettlement) {
            uint256 newAssetToTerminate = uint256(userState
                .assetToTerminateForNextRound)
                .add(_assetToTerminate);
            if (_currentRound == 2) {
                require(newAssetToTerminate <= userState.tempLocked);
                StructureData.OptionState storage previousOption = _option
                    .optionStates[_currentRound - 1];
                previousOption.totalTerminate = uint256(previousOption
                    .totalTerminate)
                    .add(_assetToTerminate).toUint128();
            } else {
                StructureData.OptionState storage onGoingOption = _option
                    .optionStates[_currentRound - 2];
                uint256 totalLocked = deriveVirtualLocked(
                    userState,
                    onGoingOption.premiumRate
                );
                require(newAssetToTerminate <= totalLocked);
                //store temporarily
                _option.assetToTerminateForNextRound = uint256(_option
                    .assetToTerminateForNextRound)
                    .add(_assetToTerminate).toUint128();
            }
            userState.assetToTerminateForNextRound = newAssetToTerminate.toUint128();
        } else {
            uint256 newAssetToTerminate = uint256(userState.assetToTerminate).add(
                _assetToTerminate
            );
            require(newAssetToTerminate <= userState.ongoingAsset);
            userState.assetToTerminate = newAssetToTerminate.toUint128();
            StructureData.OptionState storage previousOption = _option
                .optionStates[_currentRound - 1];
            previousOption.totalTerminate = uint256(previousOption.totalTerminate).add(
                _assetToTerminate
            ).toUint128();
        }
    }

    function cancelWithdrawStorage(
        StructureData.OptionData storage _option,
        address _user,
        uint256 _assetToTerminate,
        bool _underSettlement,
        uint16 _currentRound
    ) external {
        StructureData.UserState storage userState = _option.userStates[_user];
        if (_underSettlement) {
            userState.assetToTerminateForNextRound = uint256(userState
                .assetToTerminateForNextRound)
                .sub(_assetToTerminate).toUint128();
            if (_currentRound == 2) {
                StructureData.OptionState storage previousOption = _option
                    .optionStates[_currentRound - 1];
                previousOption.totalTerminate = uint256(previousOption
                    .totalTerminate)
                    .sub(_assetToTerminate).toUint128();
            } else {
                //store temporarily
                _option.assetToTerminateForNextRound = uint256(_option
                    .assetToTerminateForNextRound)
                    .sub(_assetToTerminate).toUint128();
            }
        } else {
            userState.assetToTerminate = uint256(userState.assetToTerminate).sub(
                _assetToTerminate
            ).toUint128();
            StructureData.OptionState storage previousOption = _option
                .optionStates[_currentRound - 1];
            previousOption.totalTerminate = uint256(previousOption.totalTerminate).sub(
                _assetToTerminate
            ).toUint128();
        }
    }

    function withdrawStorage(
        StructureData.OptionData storage _option,
        address _user,
        uint256 _amount,
        uint16 _currentRound,
        bool _isDeposit
    ) external {
        //require(_amount > 0, "!amount");
        StructureData.UserState storage userState = _option.userStates[_user];
        if (_isDeposit) {
            //todo: 0 out released amount if missing balance from trader
            uint256 releasedAmount = uint256(userState.releasedDepositAssetAmount);
            if (releasedAmount <= _amount) {
                uint256 redeemAmount = _amount.sub(releasedAmount);
                userState.pendingAsset = uint256(userState.pendingAsset).sub(
                    redeemAmount
                ).toUint128();
                userState.releasedDepositAssetAmount = 0;
                _option.totalReleasedDepositAssetAmount = uint256(_option
                    .totalReleasedDepositAssetAmount)
                    .sub(releasedAmount).toUint128();
                StructureData.OptionState storage optionState = _option
                    .optionStates[_currentRound];
                optionState.totalAmount = uint256(optionState.totalAmount).sub(
                    redeemAmount
                ).toUint128();
            } else {
                userState.releasedDepositAssetAmount = releasedAmount.sub(
                    _amount
                ).toUint128();
                _option.totalReleasedDepositAssetAmount = uint256(_option
                    .totalReleasedDepositAssetAmount)
                    .sub(_amount).toUint128();
            }
        } else {
            //same result as completeWithdraw
            userState.releasedCounterPartyAssetAmount = uint256(userState
                .releasedCounterPartyAssetAmount)
                .sub(_amount).toUint128();
            _option.totalReleasedCounterPartyAssetAmount = uint256(_option
                .totalReleasedCounterPartyAssetAmount)
                .sub(_amount).toUint128();
        }
    }

    function depositFor(
        StructureData.OptionData storage _option,
        address _userAddress,
        uint256 _amount,
        uint256 _toTerminate,
        uint16 _round,
        bool _isOpenRound
    ) external {
        //require(optionState.totalAmount + (_amount) <= quota[_optionId], "Not enough quota");

        StructureData.OptionState storage optionState = _option.optionStates[
            _round
        ];
        StructureData.UserState storage userState = _option.userStates[
            _userAddress
        ];
        //first time added
        if (!userState.hasState) {
            userState.hasState = true;
            _option.usersInvolved.push(_userAddress);
        }
        if (!_isOpenRound) {
            userState.tempLocked = uint256(userState.tempLocked).add(_amount).toUint128();
            if (_toTerminate > 0) {
                userState.assetToTerminateForNextRound = uint256(userState
                    .assetToTerminateForNextRound)
                    .add(_toTerminate).toUint128();
                _option.assetToTerminateForNextRound = uint256(_option
                    .assetToTerminateForNextRound)
                    .add(_toTerminate).toUint128();
            }
        } else {
            userState.pendingAsset = uint256(userState.pendingAsset).add(_amount).toUint128();
        }
        optionState.totalAmount = uint256(optionState.totalAmount).add(_amount).toUint128();
    }
}