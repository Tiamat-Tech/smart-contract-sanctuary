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

    bool public antiWhaleEnabled;
    uint256 public antiWhaleDuration = 10 minutes;
    uint256 public antiWhaleTime;
    uint256 public antiWhaleAmount;

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
        _approve(address(this), address(uniswapV2Router), ~uint256(0));

        // sellFeeRate = 0;
        // buyFeeRate = 0;
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function setWhales(address _whales) external onlyOwner {
        require(!whales[_whales]);

        whales[_whales] = true;
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

        uint256 transferFeeRate = recipient == uniswapV2Pair
            ? sellFeeRate
            : (sender == uniswapV2Pair ? buyFeeRate : 0);

        if (
            transferFeeRate > 0 &&
            sender != address(this) &&
            recipient != address(this)
        ) {
            uint256 _fee = amount.mul(transferFeeRate).div(100);
            super._transfer(sender, address(this), _fee); // TransferFee
            amount = amount.sub(_fee);
        } else {
            sweepTokenForBosses();
        }

        super._transfer(sender, recipient, amount);
    }

    function sweepTokenForBosses() internal nonReentrant {
        uint256 contractTokenBalance = balanceOf(address(this));
        if (contractTokenBalance >= tokenForBosses) {
            swapTokensForEth(tokenForBosses);
        }
    }

    // receive eth from uniswap swap
    receive() external payable {}

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
            addressForBosses, // The contract
            block.timestamp
        );
    }

    function setAddressForBosses(address _addressForBosses) external onlyOwner {
        require(_addressForBosses != address(0), "0x is not accepted here");

        addressForBosses = _addressForBosses;
    }

    function antiWhale(uint256 amount) external onlyOwner {
        require(amount > 0, "not accept 0 value");
        require(!antiWhaleEnabled);

        antiWhaleAmount = amount;
        antiWhaleTime = block.timestamp.add(antiWhaleDuration);
        antiWhaleEnabled = true;
    }
}