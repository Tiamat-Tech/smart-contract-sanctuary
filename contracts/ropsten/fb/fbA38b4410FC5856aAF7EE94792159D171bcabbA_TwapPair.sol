// SPDX-License-Identifier: GPL-3.0-or-later
// Deployed with donations via Gitcoin GR9

pragma solidity 0.7.6;

import './interfaces/ITwapPair.sol';
import './libraries/Reserves.sol';
import './TwapLPToken.sol';
import './libraries/Math.sol';
import './interfaces/IERC20.sol';
import './interfaces/ITwapFactory.sol';
import './interfaces/ITwapOracle.sol';

contract TwapPair is Reserves, TwapLPToken, ITwapPair {
    using SafeMath for uint256;

    uint256 private constant PRECISION = 10**18;

    uint256 public override mintFee = 0;
    uint256 public override burnFee = 0;
    uint256 public override swapFee = 0;

    uint256 public constant override MINIMUM_LIQUIDITY = 10**3;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public immutable override factory;
    address public override token0;
    address public override token1;
    address public override oracle;
    address public override trader;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'TP_LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function isContract(address addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function setMintFee(uint256 fee) external override {
        require(msg.sender == factory, 'TP_FORBIDDEN');
        mintFee = fee;
        emit SetMintFee(fee);
    }

    function setBurnFee(uint256 fee) external override {
        require(msg.sender == factory, 'TP_FORBIDDEN');
        burnFee = fee;
        emit SetBurnFee(fee);
    }

    function setSwapFee(uint256 fee) external override {
        require(msg.sender == factory, 'TP_FORBIDDEN');
        swapFee = fee;
        emit SetSwapFee(fee);
    }

    function setOracle(address _oracle) external override {
        require(msg.sender == factory, 'TP_FORBIDDEN');
        require(_oracle != address(0), 'TP_ADDRESS_ZERO');
        require(isContract(_oracle), 'TP_ORACLE_MUST_BE_CONTRACT');
        oracle = _oracle;
        emit SetOracle(_oracle);
    }

    function setTrader(address _trader) external override {
        require(msg.sender == factory, 'TP_FORBIDDEN');
        trader = _trader;
        emit SetTrader(_trader);
    }

    function collect(address to) external override lock {
        require(msg.sender == factory, 'TP_FORBIDDEN');
        require(to != address(0), 'TP_ADDRESS_ZERO');
        (uint256 fee0, uint256 fee1) = getFees();
        if (fee0 > 0) _safeTransfer(token0, to, fee0);
        if (fee1 > 0) _safeTransfer(token1, to, fee1);
        setFees(0, 0);
        _sync();
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TP_TRANSFER_FAILED');
    }

    function canTrade(address user) private view returns (bool) {
        return user == trader || user == factory;
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(
        address _token0,
        address _token1,
        address _oracle,
        address _trader
    ) external override {
        require(msg.sender == factory, 'TP_FORBIDDEN');
        require(_oracle != address(0), 'TP_ADDRESS_ZERO');
        require(isContract(_oracle), 'TP_ORACLE_MUST_BE_CONTRACT');
        require(isContract(_token0) && isContract(_token1), 'TP_TOKEN_MUST_BE_CONTRACT');
        token0 = _token0;
        token1 = _token1;
        oracle = _oracle;
        trader = _trader;
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external override lock returns (uint256 liquidity) {
        require(canTrade(msg.sender), 'TP_UNAUTHORIZED_TRADER');
        require(to != address(0), 'TP_ADDRESS_ZERO');
        (uint112 reserve0, uint112 reserve1) = getReserves();
        (uint256 balance0, uint256 balance1) = getBalances(token0, token1);
        uint256 amount0 = balance0.sub(reserve0);
        uint256 amount1 = balance1.sub(reserve1);

        uint256 _totalSupply = totalSupply; // gas savings
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / reserve0, amount1.mul(_totalSupply) / reserve1);
        }

        require(liquidity > 0, 'TP_INSUFFICIENT_LIQUIDITY_MINTED');
        if (mintFee > 0) {
            uint256 fee = liquidity.mul(mintFee).div(PRECISION);
            liquidity = liquidity.sub(fee);
            _mint(factory, fee);
        }
        _mint(to, liquidity);

        setReserves(balance0, balance1);

        emit Mint(msg.sender, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external override lock returns (uint256 amount0, uint256 amount1) {
        require(canTrade(msg.sender), 'TP_UNAUTHORIZED_TRADER');
        require(to != address(0), 'TP_ADDRESS_ZERO');
        uint256 _totalSupply = totalSupply; // gas savings
        require(_totalSupply > 0, 'TP_INSUFFICIENT_TOTAL_SUPPLY');
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        (uint256 balance0, uint256 balance1) = getBalances(token0, token1);
        uint256 liquidity = balanceOf[address(this)];

        if (msg.sender != factory && burnFee > 0) {
            uint256 fee = liquidity.mul(burnFee).div(PRECISION);
            liquidity = liquidity.sub(fee);
            _transfer(address(this), factory, fee);
        }
        _burn(address(this), liquidity);

        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'TP_INSUFFICIENT_LIQUIDITY_BURNED');

        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        (balance0, balance1) = getBalances(token0, token1);
        setReserves(balance0, balance1);

        emit Burn(msg.sender, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external override lock {
        require(canTrade(msg.sender), 'TP_UNAUTHORIZED_TRADER');
        require(to != address(0), 'TP_ADDRESS_ZERO');
        require(
            (amount0Out > 0 && amount1Out == 0) || (amount1Out > 0 && amount0Out == 0),
            'TP_INVALID_OUTPUT_AMOUNTS'
        );
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'TP_INSUFFICIENT_LIQUIDITY');

        {
            // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, 'TP_INVALID_TO');
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        }
        (uint256 balance0, uint256 balance1) = getBalances(token0, token1);

        if (amount0Out > 0) {
            // trading token1 for token0
            uint256 amount1In = balance1 > _reserve1 ? balance1 - _reserve1 : 0;
            require(amount1In > 0, 'TP_INSUFFICIENT_INPUT_AMOUNT');

            uint256 fee1 = amount1In.mul(swapFee).div(PRECISION);
            uint256 balance1After = balance1.sub(fee1);
            uint256 balance0After = ITwapOracle(oracle).tradeY(balance1After, _reserve0, _reserve1, data);
            require(balance0 >= balance0After, 'TP_INVALID_SWAP');
            uint256 fee0 = balance0.sub(balance0After);
            addFees(fee0, fee1);
            setReserves(balance0After, balance1After);
        } else {
            // trading token0 for token1
            uint256 amount0In = balance0 > _reserve0 ? balance0 - _reserve0 : 0;
            require(amount0In > 0, 'TP_INSUFFICIENT_INPUT_AMOUNT');

            uint256 fee0 = amount0In.mul(swapFee).div(PRECISION);
            uint256 balance0After = balance0.sub(fee0);
            uint256 balance1After = ITwapOracle(oracle).tradeX(balance0After, _reserve0, _reserve1, data);
            require(balance1 >= balance1After, 'TP_INVALID_SWAP');
            uint256 fee1 = balance1.sub(balance1After);
            addFees(fee0, fee1);
            setReserves(balance0After, balance1After);
        }

        emit Swap(msg.sender, to);
    }

    function sync() external override lock {
        require(canTrade(msg.sender), 'TP_UNAUTHORIZED_TRADER');
        _sync();
    }

    // force reserves to match balances
    function _sync() internal {
        syncReserves(token0, token1);
        uint256 tokens = balanceOf[address(this)];
        if (tokens > 0) {
            _transfer(address(this), factory, tokens);
        }
    }

    function getSwapAmount0In(uint256 amount1Out, bytes calldata data)
        public
        view
        override
        returns (uint256 swapAmount0In)
    {
        (uint112 reserve0, uint112 reserve1) = getReserves();
        uint256 balance1After = uint256(reserve1).sub(amount1Out);
        uint256 balance0After = ITwapOracle(oracle).tradeY(balance1After, reserve0, reserve1, data);
        return balance0After.sub(uint256(reserve0)).mul(PRECISION).ceil_div(PRECISION.sub(swapFee));
    }

    function getSwapAmount1In(uint256 amount0Out, bytes calldata data)
        public
        view
        override
        returns (uint256 swapAmount1In)
    {
        (uint112 reserve0, uint112 reserve1) = getReserves();
        uint256 balance0After = uint256(reserve0).sub(amount0Out);
        uint256 balance1After = ITwapOracle(oracle).tradeX(balance0After, reserve0, reserve1, data);
        return balance1After.add(1).sub(uint256(reserve1)).mul(PRECISION).ceil_div(PRECISION.sub(swapFee));
    }

    function getSwapAmount0Out(uint256 amount1In, bytes calldata data)
        public
        view
        override
        returns (uint256 swapAmount0Out)
    {
        (uint112 reserve0, uint112 reserve1) = getReserves();
        uint256 fee = amount1In.mul(swapFee).div(PRECISION);
        uint256 balance0After = ITwapOracle(oracle).tradeY(
            uint256(reserve1).add(amount1In).sub(fee),
            reserve0,
            reserve1,
            data
        );
        return uint256(reserve0).sub(balance0After);
    }

    function getSwapAmount1Out(uint256 amount0In, bytes calldata data)
        public
        view
        override
        returns (uint256 swapAmount1Out)
    {
        (uint112 reserve0, uint112 reserve1) = getReserves();
        uint256 fee = amount0In.mul(swapFee).div(PRECISION);
        uint256 balance1After = ITwapOracle(oracle).tradeX(
            uint256(reserve0).add(amount0In).sub(fee),
            reserve0,
            reserve1,
            data
        );
        return uint256(reserve1).sub(balance1After);
    }

    function getDepositAmount0In(uint256 amount0, bytes calldata data) external view override returns (uint256) {
        (uint112 reserve0, uint112 reserve1) = getReserves();
        return ITwapOracle(oracle).depositTradeXIn(amount0, reserve0, reserve1, data);
    }

    function getDepositAmount1In(uint256 amount1, bytes calldata data) external view override returns (uint256) {
        (uint112 reserve0, uint112 reserve1) = getReserves();
        return ITwapOracle(oracle).depositTradeYIn(amount1, reserve0, reserve1, data);
    }
}