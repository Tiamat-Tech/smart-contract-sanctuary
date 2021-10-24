// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "hardhat/console.sol"; // TODO: remove late

contract FlokiCity is Ownable, ERC20 {

    using SafeMath for uint;

    uint8 private _fMarketing = 3;
    uint8 private _pFMarketing = _fMarketing;
    uint8 private _fLottery = 7;
    uint8 private _pFLottery = _fLottery;

    uint private _tSupply =  1_000_000_000 * 10 ** decimals();
    uint private _numMaxEthBuyBack = 1 ether;
    uint private _numTokensSell = 1_000 * 10 ** decimals();

    mapping (address => bool) private _addressExcludedFromFee;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    address private _marketingAddr = 0x07dB86C9642b05CB3ed8CDa628dE1007DbDA3Df8; // TODO my wallet
    address private _lotteryAddr = 0x07dB86C9642b05CB3ed8CDa628dE1007DbDA3Df8; // TODO my wallet

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public buyBackEnabled = true;

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    event SwapETHForTokens(
        uint256 amountIn,
        address[] path
    );

    constructor(address routerAddr) ERC20("Floki City", "FLOKIN") {
        address addressContract = address(this);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(routerAddr);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(addressContract, _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        _addressExcludedFromFee[Ownable.owner()] = true;
        _addressExcludedFromFee[addressContract] = true;
        _addressExcludedFromFee[_marketingAddr] = true;
        _addressExcludedFromFee[_lotteryAddr] = true;
        _mint(Ownable.owner(), _tSupply);
        emit Transfer(address(0), Ownable.owner(), _tSupply);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint senderBalance = balanceOf(sender);
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        console.log("1");
        console.log("sender: %s", sender);
        console.log("recipient: %s", recipient);
        console.log("amount: %s", amount);
        if(!inSwapAndLiquify && swapAndLiquifyEnabled && (recipient == uniswapV2Pair || sender == uniswapV2Pair)){
        //if(!inSwapAndLiquify && swapAndLiquifyEnabled && recipient == uniswapV2Pair){
            console.log("2");
            bool overMinimumTokenBalance = address(this).balance >= _numMaxEthBuyBack;
            console.log("balance : %s", address(this).balance);
            if(overMinimumTokenBalance && buyBackEnabled) {
                console.log("3");
                uint contractTokenBalance = _numMaxEthBuyBack.div(100) ; // buyback 0.01 eth
                swapETHForTokens(contractTokenBalance, address(0));
            }
            overMinimumTokenBalance = balanceOf(address(this)) >= _numTokensSell;
            if(overMinimumTokenBalance && _fMarketing > 0 && _fLottery > 0) {
                console.log("4");
                uint amountMarketing = _numTokensSell * _fMarketing / (_fMarketing + _fLottery);
                uint amountLottery = _numTokensSell - amountMarketing;
                console.log("amount marketing: %s", amountMarketing);
                swapTokenFor(_marketingAddr, amountMarketing);
                swapTokenFor(_lotteryAddr, amountLottery);
            }
        }

        bool takeFee = true;
        if(_addressExcludedFromFee[sender] || _addressExcludedFromFee[recipient]){
            takeFee = false;
        }
        tokenTransfer(sender, recipient, amount, takeFee);
    }

    function tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee) {
            removeAllFee();
        }

        if(_addressExcludedFromFee[sender]) {
            transferWithoutFee(sender, recipient, amount);
        } else {
            transferWithFee(sender, recipient, amount);
        }

        if(!takeFee) {
            restoreAllFee();
        }

    }
    function transferWithFee(address sender, address recipient, uint256 _amount) private {
        (uint amountMarketing, uint amountLottery, uint amountTransferred) = getAmounts(_amount);
        ERC20._balances[sender] = ERC20._balances[sender] - _amount;
        ERC20._balances[recipient] = ERC20._balances[recipient] + amountTransferred;
        ERC20._balances[address(this)] = ERC20._balances[address(this)] + amountMarketing + amountLottery;
        emit Transfer(sender, recipient, amountTransferred);
    }
    function transferWithoutFee(address sender, address recipient, uint256 _amount) private {
        ERC20._balances[sender] = ERC20._balances[sender] - _amount;
        ERC20._balances[recipient] = ERC20._balances[recipient] + _amount;
        emit Transfer(sender, recipient, _amount);
    }

    function swapTokenFor(address recipient, uint amount) private lockTheSwap {
        uint initialBalance = address(this).balance;
        console.log("s1");
        swapTokensForEth(amount);
        uint amountTransferred =  address(this).balance - initialBalance;
        transferToAddressETH(recipient, amountTransferred);
    }

    function swapETHForTokens(uint amount, address recipient) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);
        console.log("swap amount: %s", amount);
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            recipient,
            block.timestamp + 300
        );

        emit SwapETHForTokens(amount, path);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        console.log("s1.1");

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        console.log("s1.2: %s", address(this).balance);
    }

    function getAmounts(uint _amount) private view returns (uint, uint, uint) {
        uint amountMarketing = _amount * _fMarketing / 100;
        uint amountLottery = _amount * _fLottery / 100;
        uint amountTransferred = _amount - amountMarketing - amountLottery;
        return (amountMarketing, amountLottery, amountTransferred);
    }


    function removeAllFee() private {
        if(_fMarketing == 0 && _fLottery == 0) return;

        _pFLottery = _fLottery;
        _pFMarketing = _fMarketing;
        _fLottery = 0;
        _fMarketing = 0;
    }

    function restoreAllFee() private {
        _fLottery = _pFLottery;
        _fMarketing = _pFMarketing;
    }

    function transferToAddressETH(address recipient, uint amount) private {
        payable(recipient).transfer(amount);
    }

    function getFeeMarketing() public view returns(uint8) {
        return _fMarketing;
    }

    function getFeeLottery() public view returns(uint8) {
        return _fLottery;
    }

    function setFeeMarketing(uint8 fee) public onlyOwner {
        _fMarketing = fee;
    }

    function setFeeLottery(uint8 fee) public onlyOwner {
        _fLottery = fee;
    }

    function setMarketingAddr(address addr) public onlyOwner {
        _addressExcludedFromFee[addr] = true;
        _marketingAddr = addr;
    }

    function setLotteryAddr(address addr) public onlyOwner {
        _addressExcludedFromFee[addr] = true;
        _lotteryAddr = addr;
    }

    function setNumTokensSell(uint amountWithoutDecimal) public onlyOwner {
        _numTokensSell = amountWithoutDecimal * 10 ** decimals();
    }

    function setNumMaxEthBuyBack(uint amount) public onlyOwner {
        _numMaxEthBuyBack = amount;
    }

    function getUniswapV2Pair()public view returns(address) {
        return uniswapV2Pair;
    }

    //to recieve Token native (ETH, BNB ...) from router defi when swaping
    receive() external payable {}
}