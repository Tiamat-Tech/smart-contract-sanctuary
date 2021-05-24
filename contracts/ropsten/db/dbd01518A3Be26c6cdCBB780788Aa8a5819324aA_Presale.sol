// contracts/Presale/Presale.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol';
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Presale is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20PresetMinterPauser;

    ERC20PresetMinterPauser public rugToken;

    uint256 public rugTarget; // target amount of rug to sell
    uint256 public weiTarget; // target amount of eth for presale
    uint256 public multiplier; // rugTarget ÷ weiTarget
    bool public isActive; // is the sale active
    bool public hasEnded; // has the sale been ended


    constructor(ERC20PresetMinterPauser _token, uint256 _rugTarget, uint256 _weiTarget) {
        rugToken = _token;
        rugTarget = _rugTarget;
        weiTarget = _weiTarget;
        multiplier = rugTarget.div(weiTarget);
        isActive = false;
        hasEnded = false;
    }

    function startSale() external onlyOwner {
        require(isActive == false, "Presale already started!");
        require(hasEnded == false, "Cannot restart sale!");
        isActive = true;
    }

    function pauseSale() external onlyOwner {
        require(isActive == true, "Presale not started!");
        require(hasEnded == false, "Cannot pause ended sale!");
        isActive = false;
    }

    function endSale() external onlyOwner {
        require(hasEnded == false, "Sale already ended!");
        require(isActive == true, "Presale not started!");
        isActive = false;
        hasEnded = true;
    }

    function buy() public payable {
        require(
            isActive == true,
            "Presale has not yet started!"
        );

        uint256 amount = msg.value.mul(multiplier);
        // check that amount doesnt exceed remaining balance
        require(
            amount <= rugToken.balanceOf(address(this)),
            "Exceeds amount available!"
        );

        // transfer amount
        rugToken.transfer(msg.sender, amount);
    }

    function withdrawETH() external onlyOwner {
        require(
            hasEnded == true,
            "Sale not ended!"
        );
        msg.sender.transfer(address(this).balance);
    }

    function rugBurn() external onlyOwner {
        require(
            hasEnded == true,
            "Sale not ended!"
        );

        uint256 amountToBurn = rugToken.balanceOf(address(this));
        rugToken.burn(amountToBurn);
    }

}