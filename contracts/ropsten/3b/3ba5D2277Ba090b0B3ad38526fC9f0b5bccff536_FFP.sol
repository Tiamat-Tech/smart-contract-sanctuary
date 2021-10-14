pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract FFP is ERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    address public uniswapV2Pair;
    address public marketingWallet = 0x5bABeef611BcB036aE353245Bcdcc66197f693B1;
    address[] private _excluded; //list of address that are excluded
    address public immutable deadAddress =
        0x000000000000000000000000000000000000dEaD;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 10000000000000 * 10**9; // // 1 billion=10**9  1 trillion =10**12 Quadrillion =10**15
    uint8 private _decimals = 9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal)); //total reflections
    uint256 private _tFeeTotal;
    //100% of the fees generated go to holders of the token. The percentage of fees you earn is calculated by the percentage of FFP that you own among holders.
    uint256 public _taxFee = 4; //To reward holders of the token we redistribute 4% of every transaction to all holders of the token
    uint256 private _previousTaxFee = _taxFee;
    uint256 public _liquidityFee = 0; //If we want the token to go up in value we need the liquidity pool to grow as well. This is why 4% of every transaction goes towards liquidity
    uint256 private _previousLiquidityFee = _liquidityFee;
    uint256 public _burnFee = 0; //To make coin deflationary % tokens will be burned per transaction
    uint256 private _previousBurnFee = _burnFee;
    uint256 public _marketingWalletFee = 4; //In order to keep marketing the token successfully 2% of every transaction goes towards marketing
    uint256 private _previousMarketingWalletFee = _marketingWalletFee;
    uint256 private numTokensSellToAddToLiquidity = 1 * 10**4 * 10**9; //minimum tokens to be sold to add to liquidity pool

    mapping(address => bool) private _isExcludedFromFee; //contains list of address where there are included/excluded from tax fee  --> [(address1,true),(address2,false).....]
    mapping(address => bool) private _isExcluded; //it contains list of address whether they are eligible for rewards or not(i.e holding tokens)  -->[(address1,true),(address2,false)....]
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true; //flag to enable/disable liquidity swap
    bool takeFee;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event SwapTokensForETH(uint256 amountIn, address[] path);
    event SwapAndLiquifyEnabledUpdated(bool enabled);

    IUniswapV2Router02 public uniswapV2Router;

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor() ERC20("FLOKIFRUNKPUPPY", "FFP") {
        //name,symbol
        _rOwned[_msgSender()] = _rTotal; //assigning total supply to address[0]

        // pancake bsc testnet router address-0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        // UniswapV2Router02 is deployed at 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D on the Ethereum mainnet, and the Ropsten, Rinkeby, Görli, and Kovan testnets
        // (Uni|Cake)swapV2Router02 - https://bscscan.com/address/0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F
        // QuickSwapRouter: https://explorer-mainnet.maticvigil.com/address/0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff/contracts

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[marketingWallet] = true;
        _isExcludedFromFee[deadAddress] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function setMarketingWallet(address newWallet) external onlyOwner {
        marketingWallet = newWallet;
    }

    function setTaxFee(uint256 rate) external onlyOwner {
        _taxFee = rate;
        _previousTaxFee = _taxFee;
    }

    function setLiquidityFee(uint256 rate) external onlyOwner {
        _liquidityFee = rate;
        _previousLiquidityFee = _liquidityFee;
    }

    function setBurnFee(uint256 rate) external onlyOwner {
        _burnFee = rate;
        _previousBurnFee = _burnFee;
    }

    function setMarketingWalletFee(uint256 rate) external onlyOwner {
        _marketingWalletFee = rate;
        _previousMarketingWalletFee = _marketingWalletFee;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already Included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        //need to check what will be the value of _rTotal
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**2);
    }

    function calculateLiquidityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(_liquidityFee).div(10**2);
    }

    function removeAllFee() private {
        if (_taxFee == 0 && _liquidityFee == 0) return;
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _burnFee = _previousBurnFee;
        _marketingWalletFee = _previousMarketingWalletFee;

        _taxFee = 0;
        _liquidityFee = 0;
        _burnFee = 0;
        _marketingWalletFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _burnFee = _previousBurnFee;
        _marketingWalletFee = _previousMarketingWalletFee;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        takeFee = false;

        //if any account belongs to _isExcludedFromFee account then remove the fee
         if (
            (from == uniswapV2Pair || to == uniswapV2Pair) &&
            !(_isExcludedFromFee[from] || _isExcludedFromFee[to])
        ) {
            takeFee = true;
        }


        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
        emit SwapTokensForETH(tokenAmount, path);
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
            owner(),
            block.timestamp
        );
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFees
    ) private {
        if (!takeFees) removeAllFee();

        //Calculate burn amount and marketing amount
        uint256 burnAmt = amount.mul(_burnFee).div(100);
        uint256 marketingAmt = amount.mul(_marketingWalletFee).div(100);

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(
                sender,
                recipient,
                (amount.sub(burnAmt).sub(marketingAmt))
            );
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(
                sender,
                recipient,
                (amount.sub(burnAmt).sub(marketingAmt))
            );
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(
                sender,
                recipient,
                (amount.sub(burnAmt).sub(marketingAmt))
            );
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(
                sender,
                recipient,
                (amount.sub(burnAmt).sub(marketingAmt))
            );
        } else {
            _transferStandard(
                sender,
                recipient,
                (amount.sub(burnAmt).sub(marketingAmt))
            );
        }

        //Temporarily remove fees to transfer to burn address and marketing wallet
        _taxFee = 0;
        _liquidityFee = 0;
        if(_marketingWalletFee != 0){
 //Send transfers to marketing wallet
        _transferStandard(sender, marketingWallet, marketingAmt);
        }
        if(_burnFee != 0){
  //Send transfers to burn wallet
        _transferStandard(sender, deadAddress, burnAmt);
        }

      

        //Restore tax and liquidity fees
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;

        if (!takeFees) restoreAllFee();
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidity
        );
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(
            !_isExcluded[sender],
            "Excluded addresses cannot call this function"
        );
        (uint256 rAmount, , , , , ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    // Withdraw ETH that gets stuck in contract by accident
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance); //https://fravoll.github.io/solidity-patterns/secure_ether_transfer.html#:~:text=In%20the%20early%20days%20of,the%20function%20is%20called%20on.
    }
}