// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @notice Contract exchange ERC20 tokens to another ERC20 tokens
contract ArconaERC20Sale is ERC20('Arcona', 'A'), Ownable {
    using SafeMath for uint;

    /// @notice Exchange token contract address
    IERC20 public exchangeToken;

    /// @notice Count of Exchange Token (Wei) in 1A
    uint256 public tokenPrice;

    uint256 private weiInOneToken = 1000000000000000000;

    /// @param _exchangeTokenAddress Contract address containing the tokens to be given by the user
    constructor(address _exchangeTokenAddress) {
        exchangeToken = IERC20(_exchangeTokenAddress);
    }

    /// @notice Set the price of one token that the user will receive
    /// @param _newPrice Token price (Wei)
    function setTokenPrice(uint256 _newPrice) external onlyOwner {
        tokenPrice = _newPrice;
    }

    /// @notice Exchange one token to another
    /// @param _exchangeTokensAmount Token amount (Wei)
    function exchange(uint256 _exchangeTokensAmount) external {
        require(tokenPrice > 0, "[E-85] - Token price is not set.");

        uint256 _tokensToMint = calculateTokensAmountAfterExchange(_exchangeTokensAmount);
        require(_tokensToMint >= weiInOneToken, "[E-86] - Exchange amount to low.");

        require(exchangeToken.transferFrom(msg.sender, address(this), _exchangeTokensAmount), "[E-87] - Failed to transfer token.");
        _mint(msg.sender, _tokensToMint);
    }

    /// @notice Calculate tokens amount that user receive from _exchangeTokensAmount
    /// @param _exchangeTokensAmount Token amount (Wei)
    function calculateTokensAmountAfterExchange(uint256 _exchangeTokensAmount) public view returns (uint256) {
        return _exchangeTokensAmount.mul(weiInOneToken).div(tokenPrice);
    }

    /// @notice Mint tokens
    /// @param _account The address to which the tokens will be transferred
    /// @param _amount The amount of tokens to create (Wei)
    function mint(address _account, uint256 _amount) external onlyOwner {
        _mint(_account, _amount);
    }
}