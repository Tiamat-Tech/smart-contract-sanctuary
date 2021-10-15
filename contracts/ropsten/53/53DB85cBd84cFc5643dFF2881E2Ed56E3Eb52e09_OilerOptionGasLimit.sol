// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;
pragma abicoder v2;

import {HeaderRLP} from "./lib/HeaderRLP.sol";
import {OilerOption} from "./OilerOptionBase.sol";

contract OilerOptionGasLimit is OilerOption {
    string private constant _optionType = "C";
    string private constant _name = "OilerOptionCapacity";

    constructor() OilerOption() {}

    function init(
        uint256 _strikePrice,
        uint256 _expiryTS,
        bool _put,
        address _collateralAddress
    ) external {
        super._init(_strikePrice, _expiryTS, _put, _collateralAddress);
    }

    function exercise(bytes calldata _rlp) external returns (bool) {
        require(isActive(), "OilerOptionGasLimit.exercise: not active, cannot exercise");

        uint256 blockNumber = HeaderRLP.checkBlockHash(_rlp);
        require(
            blockNumber >= startBlock,
            "OilerOptionGasLimit.exercise: can only be exercised with a block after option creation"
        );
        uint256 gasLimit = HeaderRLP.getGasLimit(_rlp);

        _exercise(gasLimit);
        return true;
    }

    function optionType() external pure override returns (string memory) {
        return _optionType;
    }

    function name() public pure override returns (string memory) {
        return _name;
    }
}