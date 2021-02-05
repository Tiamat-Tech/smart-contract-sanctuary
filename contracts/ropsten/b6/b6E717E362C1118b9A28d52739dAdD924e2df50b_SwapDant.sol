pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SwapDant is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    ERC20 public usdtToken;
    ERC20 public dantToken;

    event Swap(
        address indexed user,
        uint amountIn,
        uint amountOut
    );

    constructor(
        ERC20 _usdtToken,
        ERC20 _dantToken
    ) public {
        usdtToken = _usdtToken;
        dantToken = _dantToken;
    }

    function swap(uint256 _amountIn, uint256 _amountOut) external{
        uint256 amountOut = _amountIn.mul(1e12);
        require(_amountOut <= amountOut, 'Error amountOut');
        
        usdtToken.safeTransfer(address(this), _amountIn);
        dantToken.safeTransfer(msg.sender, amountOut);
        emit Swap(msg.sender, _amountIn, amountOut);
    }

    function withdrawETH(uint256 amount) external onlyOwner{
        (bool success, ) = msg.sender.call{value:amount}("");
        //(bool success, ) = msg.sender.call.value(amount)("");
        require(success, "Transfer failed.");
    }

     function withdrawUSDT(uint256 amount) external onlyOwner{
        usdtToken.safeTransfer(msg.sender, amount);
    }

    function withdrawDant(uint256 amount) external onlyOwner{
        dantToken.safeTransfer(msg.sender, amount);
    }
}