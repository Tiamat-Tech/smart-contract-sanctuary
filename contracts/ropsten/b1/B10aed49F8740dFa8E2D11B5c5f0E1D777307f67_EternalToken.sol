/*
    SPDX-License-Identifier: MIT
    
*/

pragma solidity ^0.8.0;

import "IUniswapV2Pair.sol";
import "IUniswapV2Factory.sol";
import "IUniswapV2Router.sol";
import "ERC20.sol";
import "Ownable.sol";

contract EternalToken is ERC20, Ownable {

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    
    address public marketingWallet;
    address public devWallet;
    address public stakingWallet;
    address public liquidityWallet;

    uint256 public marketingFee;
    uint256 public devFee;
    uint256 public stakingFee;
    uint256 public liquidityFee;
    uint256 public totalFees;

    uint256 public maxTotalFees;

    bool private swapping;

    // Allow swapAndLiquify execution sequence
    bool canSwapAndLiquify = true;

    // store addresses that a automatic market maker pairs.
    mapping (address => bool) public automatedMarketMakerPairs;

    // exclude from fees
    // useful if you need to list the token on a CEX or stake it
    mapping (address => bool) private _isExcludedFromFees;

    // events
    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event MarketingWalletUpdated(address indexed newMarketingWallet, address indexed oldMarketingWallet);
    event DevWalletUpdated(address indexed newDevWalletWallet, address indexed devWalletUpdated);
    event StakingWalletUpdated(address indexed newStakingWallet, address indexed stakingWalletUpdated);
    event LiquidityWalletUpdated(address indexed newLiquidityWallet, address indexed liquidityWalletUpdated);

    event MarketingFeeUpdated(uint256 indexed newmarketingFee);
    event DevFeeUpdated(uint256 indexed newDevFee);
    event StakingFeeUpdated(uint256 indexed newStakingFee);
    event LiquidityFeeUpdated(uint256 indexed newLiquidityFee);

    event SwapAndLiquify(
    uint256 tokensSwapped,
    uint256 ethReceived,
    uint256 tokensIntoLiqudity
    );

    constructor() ERC20("TEST2", "Test2") {
        marketingFee = 40;
        devFee = 10;
        stakingFee = 30;
        liquidityFee = 20;
        totalFees = marketingFee + devFee + stakingFee + liquidityFee;
        maxTotalFees = totalFees;

        // TODO: Change this with the wanted addresses:
        marketingWallet = msg.sender;
        devWallet = msg.sender;
        stakingWallet = msg.sender;
        liquidityWallet = msg.sender;

   
        // TODO: Change this witht he UNI v2 router:
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

         // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

        // exclude from paying fees
        excludeFromFees(marketingWallet, true);
        excludeFromFees(devWallet, true);
        excludeFromFees(stakingWallet, true);
        excludeFromFees(address(this), true);

        // TODO: Change this with the wanted mint amount:
        //    _mint is an internal function in ERC20.sol that is only called here,
        //    and CANNOT be called ever again
        _mint(owner(), 100_000_000 * (10**18));
    }

    // fallback function to receive eth
    receive() external payable {
    }

    // This is needed if we want to change DEX, or if Uniswap goes V4
    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(newAddress != address(uniswapV2Router), "the router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "DrivenX: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(automatedMarketMakerPairs[pair] != value, "automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    // Update wallets
    function updateMarketingWallet(address newMarketingWallet) public onlyOwner {
        require(newMarketingWallet != marketingWallet, "the marketing wallet is already this address");
        excludeFromFees(newMarketingWallet, true);
        emit MarketingWalletUpdated(newMarketingWallet, marketingWallet);
        marketingWallet = newMarketingWallet;
    }

    function updateDevWallet(address newDevWallet) public onlyOwner {
        require(newDevWallet != devWallet, ": The dev wallet is already this address");
        excludeFromFees(newDevWallet, true);
        emit LiquidityWalletUpdated(newDevWallet, devWallet);
        devWallet = newDevWallet;
    }

    function updateStakingWallet(address newStakingWallet) public onlyOwner {
        require(newStakingWallet != stakingWallet, ": The liquidity wallet is already this address");
        excludeFromFees(newStakingWallet, true);
        emit LiquidityWalletUpdated(newStakingWallet, stakingWallet);
        stakingWallet = newStakingWallet;
    }

    function updateLiquidityWallet(address newLiquidityWallet) public onlyOwner {
        require(newLiquidityWallet != liquidityWallet, ": The liquidity wallet is already this address");
        excludeFromFees(newLiquidityWallet, true);
        emit LiquidityWalletUpdated(newLiquidityWallet, liquidityWallet);
        liquidityWallet = newLiquidityWallet;
    }

    function updateMarketingFee(uint256 newMarketingFee) public onlyOwner {
        marketingFee = newMarketingFee;
        totalFees = totalFees = marketingFee + devFee + stakingFee;
        require(totalFees <= maxTotalFees);
        emit MarketingFeeUpdated(newMarketingFee);
    }

    function updateLiquidityFee(uint256 newLiquidityFee) public onlyOwner {
        liquidityFee = newLiquidityFee;
        totalFees = marketingFee + liquidityFee + devFee + stakingFee;
        require(totalFees <= maxTotalFees);
        emit LiquidityFeeUpdated(newLiquidityFee);
    }

    function updateDevFee(uint256 newDevFee) public onlyOwner {
        devFee = newDevFee;
        totalFees = marketingFee + liquidityFee + devFee + stakingFee;
        require(totalFees <= maxTotalFees);
        emit DevFeeUpdated(newDevFee);
    }

    function updatestakingFee(uint256 newStakingFee) public onlyOwner {
        stakingFee = newStakingFee;
        totalFees = marketingFee + liquidityFee + devFee + stakingFee;
        require(totalFees <= maxTotalFees);
        emit StakingFeeUpdated(newStakingFee);
    }

    // Allows to stop the automatic swap of fees
    function updateCanSwapAndLiquify(bool _canSwapAndLiquify) external onlyOwner {
        canSwapAndLiquify = _canSwapAndLiquify;
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    event Debug(string message, uint256 n);
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }


        // We don't swap if the contract is empty
        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= 1_000_000;

        if(
            canSwap &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            from != devWallet &&
            to != devWallet &&
            from != marketingWallet &&
            to != marketingWallet &&
            from != stakingWallet &&
            to != stakingWallet &&
            canSwapAndLiquify
        ) {

            // We avoid a recursion loop
            swapping = true;
            
            uint256 tokensForLiquidity = (contractTokenBalance * liquidityFee / 2) / (totalFees);
            
            uint256 tokensForMarketing = (contractTokenBalance * marketingFee) / totalFees;
            uint256 tokensForDev = (contractTokenBalance * devFee) / totalFees;
            uint256 tokensForStaking = (contractTokenBalance * stakingFee) / totalFees;
            emit Debug("tokenAmount", 0);
            //Send tokens to the staking contract
            super._transfer(address(this), stakingWallet, tokensForStaking);

            // We swap the tokens for ETH
            uint256 ETHBefore = address(this).balance;
            uint256 tokensToSwap = tokensForLiquidity + tokensForMarketing + tokensForDev;

            swapTokensForEth(tokensToSwap);
            uint256 EthSwapped = address(this).balance - ETHBefore; // How much did we get?

            // This is for math purposes
            uint256 swappedFees = totalFees - liquidityFee/2 - stakingFee;
            // Eth if we swapped all tokens
            uint256 hypotheticalEthBalance = (EthSwapped * totalFees) / swappedFees;
            // We compute the amount of Eth to send to each wallet
            uint256 ethForLiquidity = (hypotheticalEthBalance * liquidityFee / 2) / totalFees;
            uint256 ethForMarketing = hypotheticalEthBalance * marketingFee / totalFees;
            uint256 ethForDev = hypotheticalEthBalance * devFee / totalFees;

            // We use the eth
            addLiquidity(tokensForLiquidity, ethForLiquidity);
            payable(marketingWallet).transfer(ethForMarketing);
            payable(devWallet).transfer(ethForDev);

            // We resume normal operations
            swapping = false;
        }

        bool takeFee = !swapping;
        // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if(takeFee) {
            uint256 fees = amount*totalFees/1000;
            amount = amount - fees;

            super._transfer(from, address(this), fees);
        }

        super._transfer(from, to, amount);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        
        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityWallet,
            block.timestamp
        );
        
    }

    function swapTokensForEth(uint256 tokenAmount) private {

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }


}