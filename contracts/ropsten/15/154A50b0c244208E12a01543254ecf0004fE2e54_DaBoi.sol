//SPDX-License-Identifier: Unlicense
pragma solidity =0.8.4;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './IUniswapV2Router02.sol';
import './IUniswapV2Factory.sol';


import "hardhat/console.sol";


contract DaBoi is ERC20, Ownable {
    address payable private _marketingWallet;
    mapping (address => bool) private _blacklist;
    uint8 private _marketingFee; // 10 = 10%, 1 = 1%
    uint256 public maxTx;
    uint256 public maxWallet;
    // variables that store addresses for uniswap connection
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    // this variable holds the value of token required to initiate a uniswap exchange
//    uint256 public numTokensToExchangeForMarketing = 1e18; // 1 full token
    uint256 public numTokensToExchangeForMarketing = 1000000000000000000; // 1 full token

    // total supply: 1 mio
    // swap

    // variable that is used for lockTheSwap modifier (to protect assets during swaps)
    bool inSwapAndSend;
    // variable that stores if token swaps (with uniswap) are enabled or disabled
    bool public swapAndSendEnabled = true;

    modifier lockTheSwap {
        inSwapAndSend = true;
        _;
        inSwapAndSend = false;
    }

modifier blacklist (address account) {
        require(!_blacklist[account], "DaBoi: not possible - account is blacklisted");
        _;
    }

    constructor(address marketingWallet, uint8 initialMarketingFee, uint256 maxTx_,  uint256 maxWallet_, string memory name, string memory symbol) ERC20(name, symbol) Ownable(){
        _marketingWallet = payable(marketingWallet);
        _marketingFee = initialMarketingFee;
        maxTx = maxTx_;
        maxWallet = maxWallet_;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        // mint total supply to owner
//        _mint(_msgSender(), 1 * 1e6 * 1e18); // mint 1 million token to owner
        _mint(_msgSender(), 1000000000000000000000000); // mint 1 million token to owner

    }

    function swapAndSend(uint256 contractTokenBalance) private lockTheSwap {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), contractTokenBalance);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            contractTokenBalance,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

        uint256 contractETHBalance = address(this).balance;
        if(contractETHBalance > 0) {
            _marketingWallet.transfer(contractETHBalance);
        }
    }

    function addToBlacklist(address account) external onlyOwner returns (bool) {
        _blacklist[account] = true;
        return true;
    }
    function disableSwapAndSend() external onlyOwner{
        swapAndSendEnabled = false;
    }
    function enableSwapAndSend() external onlyOwner{
        swapAndSendEnabled = true;
    }
    function removeFromBlacklist(address account) external onlyOwner returns (bool) {
        _blacklist[account] = false;
        return true;
    }

    // TODO: WE NEED TO DISCUSS IF YOU WANT TO KEEP THIS FUNCTION
    function mint(address to, uint256 amount) external onlyOwner blacklist(to) {
        // NOTE: this function does not take maxWallet into account - any amount is possible
        _mint(to, amount);
    }

    // TODO: WE NEED TO DISCUSS IF YOU WANT TO KEEP THIS FUNCTION
    function burn(address from, uint256 amount) external {
        require(from == _msgSender(), "DaBoi: you can only burn your own tokens");
        _burn(from, amount);
    }

    function setMarketingWallet(address newWallet) external onlyOwner{
        _marketingWallet = payable(newWallet);
    }
    function setMarketingFee(uint8 newValue) external onlyOwner{
        _marketingFee = newValue;
    }

    function setNumTokensToExchangeForMarketing(uint256 newValue) external onlyOwner{
        numTokensToExchangeForMarketing = newValue;
    }

    function setMaxTx(uint256 newMaxTx) external onlyOwner {
        // if set to 0,no transfers/buys/sells are possible at all
        maxTx = newMaxTx;
    }

    function setMaxWallet(uint256 newMaxWallet) external onlyOwner {
        // if set to 0 or too low,no transfers/buys/sells are possible at all
        maxWallet = newMaxWallet;
    }

    function transfer(address recipient, uint256 amount) public virtual override blacklist(recipient) returns (bool) {
        // make sure transfer does not exceed maxTx amount
        require(amount <= maxTx, "DaBoi: transfer amount exceeds max transaction amount");

        // make sure recipient wallet does not exceed maxWallet value
        require(balanceOf(recipient) + amount <= maxWallet, "DaBoi: transfer amount exceeds max transaction amount");

        // transfer the marketing fee amount from token owner to this contract
        uint256 marketingFeeAmount = amount * _marketingFee / 100;
        _transfer(_msgSender(), address(this), marketingFeeAmount);

        // check if contract balance is above swap limit (=initiate uniswap swap from token into ETH)
        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >= numTokensToExchangeForMarketing;

        // send the remaining amount of token to the recipient
        _transfer(_msgSender(), recipient, amount - marketingFeeAmount);


        if (
            overMinTokenBalance &&  // contract balance exceeds swap threshold
            !inSwapAndSend &&       // no swap is currently in progress
            //            _msgSender() != uniswapV2Pair &&       // transaction is not coming from uniswap
            swapAndSendEnabled      // uniswap swapping is generally activated
        ) {
            swapAndSend(contractTokenBalance);
        }

        // send the marketing fee directly to the marketing wallet
        //_transfer(_msgSender(), _marketingWallet, amount * _marketingFee / 100);
        return true;
    }

}