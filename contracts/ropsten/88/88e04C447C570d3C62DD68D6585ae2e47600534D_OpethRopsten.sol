// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Opeth} from "../Opeth.sol";

contract OpethRopsten is Opeth {
    function isSettlementAllowed() public view override returns (bool) {
        (
            address _collateralAsset,
            address _underlyingAsset,
            address _strikeAsset,
            /* uint _strikePrice */,
            uint _expiryTimestamp,
            /* bool isPut */
        ) = oToken.getOtokenDetails();
        return controller.isSettlementAllowed(_underlyingAsset, _strikeAsset, _collateralAsset, _expiryTimestamp);
    }
}