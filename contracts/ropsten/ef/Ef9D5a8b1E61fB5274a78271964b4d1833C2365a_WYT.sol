pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicensed
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";


interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract WYT is Context, ERC20, ERC20Capped, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public immutable uniswapV2Router;
    IERC20 public immutable WBTCV2;
    IERC20 public immutable UNIV2;
    address payable private _wallet;

    struct Assets {
        uint256 ETH;
        uint256 UNI;
        uint256 WBTC;
    }

    mapping (address=> Assets) public _assets;
    event _deposit(uint256 ETH, uint256 UNI, uint256 WBTC, uint256 WYT);
    event _withdraw(uint256 ETH, uint256 UNI, uint256 WBTC, uint256 WYT);

    constructor() ERC20("TestToken", "T1") ERC20Capped(1000000 *10**18) {
        
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        WBTCV2 = IERC20(0xBde8bB00A7eF67007A96945B3a3621177B615C44);
        UNIV2 = IERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
        _wallet = payable(msg.sender);
        
    }
    function _mint(
        address account, 
        uint256 amount
    ) internal virtual override (ERC20, ERC20Capped) {
        require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
    }

    fallback () external payable {
        deposit();
    }

    receive () external payable {
        deposit();
    }

    function deposit() public payable {
        require(msg.value >= 1 ether, "must be greater than or equal to 1 ether");
        uint256 total = msg.value;
        uint256 total40 = total.mul(40).div(100);
        uint256 total20 = total.mul(20).div(100);
        
        uint256 initialWBTCBalance = WBTCV2.balanceOf(address(this));
        // swap ETH for WBTC
        swapEthForWBTC(total40);
        // how much WBTC did we just swap into?
        uint256 newWBTCBalance = WBTCV2.balanceOf(address(this)).sub(initialWBTCBalance);


        uint256 initialUNIBalance = UNIV2.balanceOf(address(this));
        // swap tokens for UNI
        swapEthForUNI(total20); 
        uint256 newUNIBalance = UNIV2.balanceOf(address(this)).sub(initialUNIBalance);

        _assets[msg.sender].ETH += total.mul(40).div(100);
        _assets[msg.sender].UNI += newUNIBalance;
        _assets[msg.sender].WBTC += newWBTCBalance;

        _mint(msg.sender, msg.value);
        emit _deposit(total.mul(40).div(100), newUNIBalance, newWBTCBalance, msg.value);
    }
    function swapEthForWBTC(uint256 tokenAmount) private {
        // generate the uniswap pair path of token weth -> token
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = 0xBde8bB00A7eF67007A96945B3a3621177B615C44;

        // make the swap
        uniswapV2Router.swapExactETHForTokens{value: tokenAmount}(
            0,
            path,
            address(this),
            block.timestamp+100
        );
    }
    function swapEthForUNI(uint256 tokenAmount) private {
        // generate the uniswap pair path of weth -> token 
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

        // make the swap
        uniswapV2Router.swapExactETHForTokens{value: tokenAmount}(
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function withdraw() public {
        // 1% fees
        uint256 accountBalance = ERC20.balanceOf(msg.sender);
        require(accountBalance > 0, "You need to deposit first");
        uint256 ETH = _assets[msg.sender].ETH;
        uint256 WBTC = _assets[msg.sender].WBTC;
        uint256 UNI = _assets[msg.sender].UNI;
        
        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        swapUNIForEth(UNI);
        swapWBTCForEth(WBTC);
        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        uint256 refund = ETH + newBalance;
        refund = refund.mul(99).div(100);
        payable(msg.sender).transfer(refund);
        _burn(msg.sender, accountBalance);
        
        emit _withdraw(refund, UNI, WBTC, newBalance);
    }
    function swapWBTCForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = 0xBde8bB00A7eF67007A96945B3a3621177B615C44;
        path[1] = uniswapV2Router.WETH();

        WBTCV2.approve(address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }
    function swapUNIForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        path[1] = uniswapV2Router.WETH();

        UNIV2.approve(address(uniswapV2Router), tokenAmount);

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