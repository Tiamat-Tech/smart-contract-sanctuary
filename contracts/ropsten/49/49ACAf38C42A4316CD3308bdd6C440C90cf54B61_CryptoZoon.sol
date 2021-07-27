// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Uniswap.sol";
import "./ZoonERC20.sol";

contract CryptoZoon is ZoonERC20, ReentrancyGuard {
    using SafeMath for uint256;

    mapping(address => bool) whales;
    uint256 public maxSupply = 1000 * 10**6 * 10**18;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    mapping(address => bool) private isExcludedFromFee;
    bool public antiWhaleEnabled;
    uint256 public antiWhaleDuration = 15 minutes;
    uint256 public antiWhaleTime;
    uint256 public antiWhaleAmount;

    uint256 private minimumTokensBeforeSwap = 20000 * 10**18;

    constructor(string memory name, string memory symbol)
        ZoonERC20(name, symbol)
    {
        _mint(_msgSender(), maxSupply.sub(amountFarm).sub(amountPlayToEarn));
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function setWhales(address _whales) external onlyOwner {
        require(!whales[_whales]);

        whales[_whales] = true;
    }

    function excludeFromFee(address _address, bool _b) public onlyOwner {
        isExcludedFromFee[_address] = _b;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (
            antiWhaleTime > block.timestamp &&
            amount > antiWhaleAmount &&
            whales[sender]
        ) {
            revert("Anti Whale");
        }
        bool takeFee = true;
        if (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) {
            takeFee = false;
        }

        uint256 transferFeeRate = recipient == uniswapV2Pair
            ? sellFeeRate
            : (sender == uniswapV2Pair ? buyFeeRate : 0);

        if (transferFeeRate > 0 && takeFee) {
            uint256 _fee = amount.mul(transferFeeRate).div(100);
            uint256 contractTokenBalance = balanceOf(address(this));

            super._transfer(sender, address(this), _fee); // TransferFee
            amount = amount.sub(_fee);

            if (contractTokenBalance >= minimumTokensBeforeSwap) {
                swapTokens(contractTokenBalance);
            }
        }

        super._transfer(sender, recipient, amount);
    }

    function swapTokens(uint256 contractTokenBalance) private nonReentrant {
        _approve(address(this), address(uniswapV2Router), ~uint256(0));

        swapTokensForEth(contractTokenBalance);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            marketingAddress,
            block.timestamp
        );
    }

    function setMarketingAddress(address _marketingAddress) external onlyOwner {
        require(_marketingAddress != address(0), "0x is not accepted here");

        marketingAddress = _marketingAddress;
    }

    function antiWhale(uint256 amount) external onlyOwner {
        require(amount > 0, "not accept 0 value");
        require(!antiWhaleEnabled);

        antiWhaleAmount = amount;
        antiWhaleTime = block.timestamp.add(antiWhaleDuration);
        antiWhaleEnabled = true;
    }
}