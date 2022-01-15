// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TokenASwapB {
    using SafeMath for uint256;
    string public name = "VABVA Migration Contract";

    address public tokenA = 0xd632B4ed94B1FDC37f36ac43cbB5785Da32e9bB8;
    address public tokenB = 0x6F81D7f8e6084146C659B15470b333F7Ab4e22ed;
    address public owner = 0x51A1318fC8c8822E7461A3054599b5F5EFE94D5F;

    uint256 public rateConversion = 1e9;

    event TokensSwaped(
        address account,
        address token,
        uint256 amount,
        uint256 rate
    );

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "The caller of this function can only be the owner"
        );
        _;
    }

    constructor() {}

    function TokenToVABVA(uint256 _amountToken) public {
        uint256 AmountTokenB = _amountToken.mul(rateConversion);
        require(
            IERC20(tokenB).balanceOf(address(this)) >= AmountTokenB,
            "Contract doesn't have enough TokenB"
        );
        require(
            IERC20(tokenA).balanceOf(msg.sender) >= _amountToken,
            "User doesn't have enough TokenA"
        );
        require(
            IERC20(tokenA).allowance(msg.sender, address(this)) >= _amountToken,
            "Increase Token Allowance for Swap contract"
        );

        // Transfer Token A Away from User
        IERC20(tokenA).transferFrom(msg.sender, address(this), _amountToken);
        // Transfer Tokens B to the user
        IERC20(tokenB).transfer(msg.sender, AmountTokenB);
        emit TokensSwaped(
            msg.sender,
            address(tokenB),
            _amountToken,
            AmountTokenB
        );
    }

    function VABVAToToken(uint256 _amountVABVA) public {
        uint256 TokenAmount = _amountVABVA.div(rateConversion).mul(75).div(100);

        // Require that EthSwap has enough tokens
        require(
            IERC20(tokenA).balanceOf(address(this)) >= TokenAmount,
            "Contract doesn't have enough TokenB"
        );
        require(
            IERC20(tokenB).balanceOf(msg.sender) >= _amountVABVA,
            "User doesn't have enough TokenA"
        );
        require(
            IERC20(tokenB).allowance(msg.sender, address(this)) >= _amountVABVA,
            "Increase VABVA Allowance for Swap contract"
        );

        // Transfer Token A Away from User
        IERC20(tokenB).transferFrom(msg.sender, address(this), _amountVABVA);
        // Transfer Tokens B to the user
        IERC20(tokenA).transfer(msg.sender, TokenAmount);
        emit TokensSwaped(
            msg.sender,
            address(tokenB),
            _amountVABVA,
            TokenAmount
        );
    }

    function emergencyTransfer(address _token, uint256 _amount)
        public
        onlyOwner
    {
        require(
            IERC20(_token).balanceOf(address(this)) >= _amount,
            "Contract doesn't have enough TokenB"
        );
        IERC20(_token).transfer(owner, _amount);
    }
}