pragma solidity ^0.8.0;

import "ERC20.sol";
import "SafeMath.sol";
import "ERC20Burnable.sol";

contract SportyInu is ERC20 {
    using SafeMath for uint256;
    uint256 public BURN = 2;
    uint256 public FEES = 3;
    address public owner;
    address public feesOwner;
    bool public TRANSFER_FEES_ENABLED = true;
    bool public BURN_ENABALED = true;
    mapping(address => bool) public excludedFromTax;
    
    constructor() public ERC20("SportyInu", "SPINU") {
        _mint(msg.sender, 10000000000000000000000000000000);
        owner = msg.sender;
        feesOwner = owner;
        excludedFromTax[feesOwner] = true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        if(excludedFromTax[msg.sender] == true){
            _transfer(_msgSender(), recipient, amount);
        } else {
            
            uint256 burnAmount = amount.mul(BURN) / 100;
            uint256 feeAmount = amount.mul(FEES) / 100;
            if(BURN_ENABALED == true && TRANSFER_FEES_ENABLED == true){
                _burn(_msgSender(), burnAmount);
                _transfer(_msgSender(), feesOwner, feeAmount);
                _transfer(_msgSender(), recipient, amount.sub(burnAmount).sub(feeAmount));
            }
            if(BURN_ENABALED == true && TRANSFER_FEES_ENABLED == false){
                _burn(_msgSender(), burnAmount);
                _transfer(_msgSender(), recipient, amount.sub(burnAmount));

            }
            if(BURN_ENABALED == false && TRANSFER_FEES_ENABLED == true){
                _transfer(_msgSender(), feesOwner, feeAmount);
                _transfer(_msgSender(), recipient, amount.sub(feeAmount));
            }
        
        }
        return true;
    }

    function setTransferFees(bool new_enabaled, uint256 newTransferFee) public returns(bool){
        require(msg.sender == owner, "You must be the owner!");
        TRANSFER_FEES_ENABLED = new_enabaled;
        FEES = newTransferFee;
        return true;
    }

    function setBurnFees(bool new_enabaled, uint256 newBurnFee) public returns(bool){
        //require(msg.sender == owner, "You must be the owner!");
        BURN_ENABALED = new_enabaled;
        BURN = newBurnFee;
        return true;
    }

    function setOwner(address newOwner) public returns(bool){
        require(msg.sender == owner, "You must be the owner!");
        excludedFromTax[owner] = false;
        owner = newOwner;
        excludedFromTax[newOwner] = true;
        return true;
    }

    function setFeeOwner(address newFeeOwner) public returns(bool){
        require(msg.sender == feesOwner, "You must be the owner!");
        excludedFromTax[feesOwner] = false;
        feesOwner = newFeeOwner;
        excludedFromTax[newFeeOwner] = true;
        return true;
    }
}