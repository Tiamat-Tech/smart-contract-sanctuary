// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ERC20Base.sol";
import "../features/ERC20BurnFeature.sol";
import "../features/TxFeeFeature.sol";

contract BurnTxFeeTemplate is ERC20Base, ERC20BurnFeature, TxFeeFeature {
    function initialize(
        string memory name_, 
        string memory symbol_, 
        uint8 decimals_, 
        uint256 amount_,
        uint256 txFee,
        address txFeeBeneficiary
    ) 
        public initializer 
    {
        ERC20Base.initialize(name_, symbol_, decimals_, amount_);
        __ERC20TxFeeFeature_init(txFee, txFeeBeneficiary);
    }

    function decimals() public view override(ERC20Base, ERC20Upgradeable) returns (uint8) {
        return ERC20Base.decimals();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Upgradeable, TxFeeFeature) {
        TxFeeFeature._beforeTokenTransfer(from, to, amount);
        ERC20Upgradeable._beforeTokenTransfer(from, to, amount);
    }
}