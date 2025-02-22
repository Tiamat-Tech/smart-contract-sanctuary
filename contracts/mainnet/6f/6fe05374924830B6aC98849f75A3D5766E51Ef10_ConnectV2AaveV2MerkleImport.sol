pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { TokenInterface, AccountInterface } from "../../../../../common/interfaces.sol";
import { AaveInterface, ATokenInterface } from "./interfaces.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";
import { Variables } from "./variables.sol";

abstract contract AaveResolver is Helpers, Events {
    function _TransferAtokens(
        uint _length,
        AaveInterface aave,
        ATokenInterface[] memory atokenContracts,
        uint[] memory amts,
        address[] memory tokens,
        address userAccount
    ) internal {
        for (uint i = 0; i < _length; i++) {
            if (amts[i] > 0) {
                uint256 _amt = amts[i];
                require(atokenContracts[i].transferFrom(userAccount, address(this), _amt), "allowance?");
                
                if (!getIsColl(tokens[i], address(this))) {
                    aave.setUserUseReserveAsCollateral(tokens[i], true);
                }
            }
        }
    }

    function _borrowOne(AaveInterface aave, address token, uint amt, uint rateMode) private {
        aave.borrow(token, amt, rateMode, referalCode, address(this));
    }

    function _paybackBehalfOne(AaveInterface aave, address token, uint amt, uint rateMode, address user) private {
        aave.repay(token, amt, rateMode, user);
    }

    function _BorrowStable(
        uint _length,
        AaveInterface aave,
        address[] memory tokens,
        uint256[] memory amts
    ) internal {
        for (uint i = 0; i < _length; i++) {
            if (amts[i] > 0) {
                _borrowOne(aave, tokens[i], amts[i], 1);
            }
        }
    }

    function _BorrowVariable(
        uint _length,
        AaveInterface aave,
        address[] memory tokens,
        uint256[] memory amts
    ) internal {
        for (uint i = 0; i < _length; i++) {
            if (amts[i] > 0) {
                _borrowOne(aave, tokens[i], amts[i], 2);
            }
        }
    }

    function _PaybackStable(
        uint _length,
        AaveInterface aave,
        address[] memory tokens,
        uint256[] memory amts,
        address user
    ) internal {
        for (uint i = 0; i < _length; i++) {
            if (amts[i] > 0) {
                _paybackBehalfOne(aave, tokens[i], amts[i], 1, user);
            }
        }
    }

    function _PaybackVariable(
        uint _length,
        AaveInterface aave,
        address[] memory tokens,
        uint256[] memory amts,
        address user
    ) internal {
        for (uint i = 0; i < _length; i++) {
            if (amts[i] > 0) {
                _paybackBehalfOne(aave, tokens[i], amts[i], 2, user);
            }
        }
    }

    function getBorrowAmount(address _token, address userAccount) 
        internal
        view
        returns
    (
        uint256 stableBorrow,
        uint256 variableBorrow
    ) {
        (
            ,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress
        ) = aaveData.getReserveTokensAddresses(_token);

        stableBorrow = ATokenInterface(stableDebtTokenAddress).balanceOf(userAccount);
        variableBorrow = ATokenInterface(variableDebtTokenAddress).balanceOf(userAccount);
    }
}

contract AaveImportHelpers is AaveResolver {
    struct ImportData {
        uint[] supplyAmts;
        uint[] totalBorrowAmts;
        uint[] variableBorrowAmts;
        uint[] stableBorrowAmts;
        address[] _supplyTokens;
        address[] _borrowTokens;
        ATokenInterface[] aTokens;
        uint[] supplySplitAmts;
        uint[] variableBorrowSplitAmts;
        uint[] stableBorrowSplitAmts;
        uint[] supplyFinalAmts;
        uint[] variableBorrowFinalAmts;
        uint[] stableBorrowFinalAmts;
        uint[] totalBorrowAmtsFinalAmts;
        uint[] totalBorrowAmtsSplitAmts;
    }

    struct ImportInputData {
        address[] supplyTokens;
        address[] borrowTokens;
        bool convertStable;
        uint256 times;
        bool isFlash;
        uint256 index;
        uint256 rewardAmount;
        uint256 networthAmount;
        bytes32[] merkleProof;
    }

    function getBorrowAmounts (
        address userAccount,
        AaveInterface aave,
        ImportInputData memory inputData,
        ImportData memory data
    ) internal returns(ImportData memory) {
        if (inputData.borrowTokens.length > 0) {
            data._borrowTokens = new address[](inputData.borrowTokens.length);
            data.variableBorrowAmts = new uint[](inputData.borrowTokens.length);
            data.stableBorrowAmts = new uint[](inputData.borrowTokens.length);
            data.totalBorrowAmts = new uint[](inputData.borrowTokens.length);
            data.variableBorrowSplitAmts = new uint256[](inputData.borrowTokens.length);
            data.variableBorrowFinalAmts = new uint256[](inputData.borrowTokens.length);
            data.stableBorrowSplitAmts = new uint256[](inputData.borrowTokens.length);
            data.stableBorrowFinalAmts = new uint256[](inputData.borrowTokens.length);
            data.totalBorrowAmtsSplitAmts = new uint256[](inputData.borrowTokens.length);
            data.totalBorrowAmtsFinalAmts = new uint256[](inputData.borrowTokens.length);

            if (inputData.times > 0) {
                for (uint i = 0; i < inputData.borrowTokens.length; i++) {
                    for (uint j = i; j < inputData.borrowTokens.length; j++) {
                        if (j != i) {
                            require(inputData.borrowTokens[i] != inputData.borrowTokens[j], "token-repeated");
                        }
                    }
                }


                for (uint256 i = 0; i < inputData.borrowTokens.length; i++) {
                    address _token = inputData.borrowTokens[i] == ethAddr ? wethAddr : inputData.borrowTokens[i];
                    data._borrowTokens[i] = _token;

                    (
                        data.stableBorrowAmts[i],
                        data.variableBorrowAmts[i]
                    ) = getBorrowAmount(_token, userAccount);

                    data.totalBorrowAmts[i] = add(data.stableBorrowAmts[i], data.variableBorrowAmts[i]);

                    if (data.totalBorrowAmts[i] > 0) {
                        uint256 _amt = inputData.times == 1 ? data.totalBorrowAmts[i] : uint256(-1);
                        TokenInterface(_token).approve(address(aave), _amt);
                    }
                }

                if (inputData.times == 1) {
                    data.variableBorrowFinalAmts = data.variableBorrowAmts;
                    data.stableBorrowFinalAmts = data.stableBorrowAmts;
                    data.totalBorrowAmtsFinalAmts = data.totalBorrowAmts;
                } else {
                    for (uint i = 0; i < data.totalBorrowAmts.length; i++) {
                        data.variableBorrowSplitAmts[i] = data.variableBorrowAmts[i] / inputData.times;
                        data.variableBorrowFinalAmts[i] = sub(data.variableBorrowAmts[i], mul(data.variableBorrowSplitAmts[i], sub(inputData.times, 1)));
                        data.stableBorrowSplitAmts[i] = data.stableBorrowAmts[i] / inputData.times;
                        data.stableBorrowFinalAmts[i] = sub(data.stableBorrowAmts[i], mul(data.stableBorrowSplitAmts[i], sub(inputData.times, 1)));
                        data.totalBorrowAmtsSplitAmts[i] = data.totalBorrowAmts[i] / inputData.times;
                        data.totalBorrowAmtsFinalAmts[i] = sub(data.totalBorrowAmts[i], mul(data.totalBorrowAmtsSplitAmts[i], sub(inputData.times, 1)));
                    }
                }
            }
        }
        return data;
    }

    function getBorrowFinalAmounts (
        address userAccount,
        ImportInputData memory inputData,
        ImportData memory data
    ) internal view returns(
        uint[] memory variableBorrowFinalAmts,
        uint[] memory stableBorrowFinalAmts,
        uint[] memory totalBorrowAmtsFinalAmts
    ) {    
        if (inputData.borrowTokens.length > 0) {
            variableBorrowFinalAmts = new uint256[](inputData.borrowTokens.length);
            stableBorrowFinalAmts = new uint256[](inputData.borrowTokens.length);
            totalBorrowAmtsFinalAmts = new uint[](inputData.borrowTokens.length);

            if (inputData.times > 0) {
                for (uint i = 0; i < data._borrowTokens.length; i++) {
                    address _token = data._borrowTokens[i];
                    (
                        stableBorrowFinalAmts[i],
                        variableBorrowFinalAmts[i]
                    ) = getBorrowAmount(_token, userAccount);

                    totalBorrowAmtsFinalAmts[i] = add(stableBorrowFinalAmts[i], variableBorrowFinalAmts[i]);
                }
            }
        }
    }

    function getSupplyAmounts (
        address userAccount,
        ImportInputData memory inputData,
        ImportData memory data
    ) internal view returns(ImportData memory) {
        data.supplyAmts = new uint[](inputData.supplyTokens.length);
        data._supplyTokens = new address[](inputData.supplyTokens.length);
        data.aTokens = new ATokenInterface[](inputData.supplyTokens.length);
        data.supplySplitAmts = new uint[](inputData.supplyTokens.length);
        data.supplyFinalAmts = new uint[](inputData.supplyTokens.length);

        for (uint i = 0; i < inputData.supplyTokens.length; i++) {
            for (uint j = i; j < inputData.supplyTokens.length; j++) {
                if (j != i) {
                    require(inputData.supplyTokens[i] != inputData.supplyTokens[j], "token-repeated");
                }
            }
        }

        for (uint i = 0; i < inputData.supplyTokens.length; i++) {
            address _token = inputData.supplyTokens[i] == ethAddr ? wethAddr : inputData.supplyTokens[i];
            (address _aToken, ,) = aaveData.getReserveTokensAddresses(_token);
            data._supplyTokens[i] = _token;
            data.aTokens[i] = ATokenInterface(_aToken);
            data.supplyAmts[i] = data.aTokens[i].balanceOf(userAccount);
        }

        if ((inputData.times == 1 && inputData.isFlash) || inputData.times == 0) {
            data.supplyFinalAmts = data.supplyAmts;
        } else {
            for (uint i = 0; i < data.supplyAmts.length; i++) {
                uint _times = inputData.isFlash ? inputData.times : inputData.times + 1;
                data.supplySplitAmts[i] = data.supplyAmts[i] / _times;
                data.supplyFinalAmts[i] = sub(data.supplyAmts[i], mul(data.supplySplitAmts[i], sub(_times, 1)));
            }
        }

        return data;
    }

    function getSupplyFinalAmounts(
        address userAccount,
        ImportInputData memory inputData,
        ImportData memory data
    ) internal view returns(uint[] memory supplyFinalAmts) {
        supplyFinalAmts = new uint[](inputData.supplyTokens.length);

        for (uint i = 0; i < data.aTokens.length; i++) {
            supplyFinalAmts[i] = data.aTokens[i].balanceOf(userAccount);
        }
    }
}

contract AaveImportResolver is AaveImportHelpers, Variables {
    constructor(address _instaAaveV2Merkle) Variables(_instaAaveV2Merkle) {}

    function _importAave(
        address userAccount,
        ImportInputData memory inputData
    ) internal returns (string memory _eventName, bytes memory _eventParam) {
        require(AccountInterface(address(this)).isAuth(userAccount), "user-account-not-auth");

        require(inputData.supplyTokens.length > 0, "0-length-not-allowed");

        ImportData memory data;

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        data = getBorrowAmounts(userAccount, aave, inputData, data);
        data = getSupplyAmounts(userAccount, inputData, data);

        if (!inputData.isFlash && inputData.times > 0) {
            _TransferAtokens(
                inputData.supplyTokens.length,
                aave,
                data.aTokens,
                data.supplySplitAmts,
                data._supplyTokens,
                userAccount
            );
        } else if (inputData.times == 0) {
            _TransferAtokens(
                inputData.supplyTokens.length,
                aave,
                data.aTokens,
                data.supplyFinalAmts,
                data._supplyTokens,
                userAccount
            );
        }

        for (uint i = 0; i < inputData.times; i++) {
            if (i == sub(inputData.times, 1)) {

                if (!inputData.isFlash && inputData.times == 1) {
                    data.supplyFinalAmts = getSupplyFinalAmounts(userAccount, inputData, data);
                }

                if (inputData.times > 1) {
                    (
                        data.variableBorrowFinalAmts,
                        data.stableBorrowFinalAmts,
                        data.totalBorrowAmtsFinalAmts
                    ) = getBorrowFinalAmounts(userAccount, inputData, data);
                    
                    data.supplyFinalAmts = getSupplyFinalAmounts(userAccount, inputData, data);
                }

                if (inputData.convertStable) {
                    _BorrowVariable(inputData.borrowTokens.length, aave, data._borrowTokens, data.totalBorrowAmtsFinalAmts);
                } else {
                    _BorrowStable(inputData.borrowTokens.length, aave, data._borrowTokens, data.stableBorrowFinalAmts);
                    _BorrowVariable(inputData.borrowTokens.length, aave, data._borrowTokens, data.variableBorrowFinalAmts);
                }

                _PaybackStable(inputData.borrowTokens.length, aave, data._borrowTokens, data.stableBorrowFinalAmts, userAccount);
                _PaybackVariable(inputData.borrowTokens.length, aave, data._borrowTokens, data.variableBorrowFinalAmts, userAccount);
                _TransferAtokens(inputData.supplyTokens.length, aave, data.aTokens, data.supplyFinalAmts, data._supplyTokens, userAccount);
            } else {
                if (inputData.convertStable) {
                    _BorrowVariable(inputData.borrowTokens.length, aave, data._borrowTokens, data.totalBorrowAmtsSplitAmts);
                } else {
                    _BorrowStable(inputData.borrowTokens.length, aave, data._borrowTokens, data.stableBorrowSplitAmts);
                    _BorrowVariable(inputData.borrowTokens.length, aave, data._borrowTokens, data.variableBorrowSplitAmts);
                }

                _PaybackStable(inputData.borrowTokens.length, aave, data._borrowTokens, data.stableBorrowSplitAmts, userAccount);
                _PaybackVariable(inputData.borrowTokens.length, aave, data._borrowTokens, data.variableBorrowSplitAmts, userAccount);
                _TransferAtokens(inputData.supplyTokens.length, aave, data.aTokens, data.supplySplitAmts, data._supplyTokens, userAccount);
            }
        }

        if (inputData.index != 0) {
            instaAaveV2Merkle.claim(
                inputData.index,
                userAccount,
                inputData.rewardAmount,
                inputData.networthAmount,
                inputData.merkleProof,
                inputData.supplyTokens,
                inputData.borrowTokens,
                data.supplyAmts,
                data.totalBorrowAmts
            );
        }

        _eventName = "LogAaveV2Import(address,bool,address[],address[],uint256[],uint256[],uint256[])";
        _eventParam = abi.encode(
            userAccount,
            inputData.convertStable,
            inputData.supplyTokens,
            inputData.borrowTokens,
            data.supplyAmts,
            data.stableBorrowAmts,
            data.variableBorrowAmts
        );
    }

    // function importAave(
    //     uint256 index,
    //     address userAccount,
    //     address[] calldata supplyTokens,
    //     address[] calldata borrowTokens,
    //     bool convertStable,
    //     uint256 times,
    //     bool isFlash,
    //     uint256 rewardAmount,
    //     uint256 networthAmount,
    //     bytes32[] calldata merkleProof
    // ) external payable returns (string memory _eventName, bytes memory _eventParam) {
    function importAave(
        address userAccount,
        ImportInputData memory inputData
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {

        (_eventName, _eventParam) = _importAave(userAccount, inputData);
    }


    function migrateAave(
        ImportInputData memory inputData
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        (_eventName, _eventParam) = _importAave(msg.sender, inputData);
    }
}

contract ConnectV2AaveV2MerkleImport is AaveImportResolver {
    constructor(address _instaAaveV2Merkle) public AaveImportResolver(_instaAaveV2Merkle) {}

    string public constant name = "AaveV2-Merkle-Import-v1";
}