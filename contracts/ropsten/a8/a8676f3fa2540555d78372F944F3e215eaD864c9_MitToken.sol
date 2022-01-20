// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol" ;
import "@openzeppelin/contracts/utils/math/SafeMath.sol" ;
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol" ;
contract MitToken is ERC20PresetMinterPauser {

    address public feeAddr ;
    uint256 public feeRate ;

    constructor(uint256 initialSupply, address _feeAddr, uint256 _feeRate) ERC20PresetMinterPauser("MIT Token", "MIT"){
        // start init mint owner
        _mint(_msgSender(), formatDecimals(initialSupply)) ;

        // init fee
        feeAddr = _feeAddr ;
        feeRate = _feeRate ;
    }

    // update feeAddr
    function setFeeAddr(address _feeAddr) external returns(bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MitToken : must have Admin role to setFeeAddr");
        feeAddr = _feeAddr ;
        return true ;
    }

    // update feeRate
    function setFeeRate(uint256 _feeRate) external returns(bool){
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MitToken : must have Admin role to setFeeRate");
        feeRate = _feeRate ;
        return true ;
    }

    // cal amount by base
    function formatDecimals(uint256 _value) internal view returns (uint256) {
        return _value * 10 ** uint256(decimals());
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override(ERC20) {
        // cal fee
        (bool ok, uint256 result) = SafeMath.tryMul(amount, feeRate) ;
        require(ok, "ERC20: transfer excessive amount of transfer!") ;
        uint256 feeAmount = SafeMath.div(result, uint256(100)) ;

        // transfer fee
        if(feeAmount > 0){
            if(feeAddr != address(0)) {
                super._transfer(sender, feeAddr, feeAmount) ;
            } else {
                feeAmount = 0 ;
            }
        }

        // transfer other
        super._transfer(sender, recipient, amount - feeAmount) ;
    }
}