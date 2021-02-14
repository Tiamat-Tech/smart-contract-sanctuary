pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./ERC20.sol";

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

interface IUniswapV2ERC20 {
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


contract bananas is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    
    // Transaction Fees
    uint32 public txFee; 
    uint32 public feeDivisor;

    // Feeless Address Mapping
    mapping(address => bool) public feeless;
    mapping(address=> bool) public minters;


    // Events
    event feeReceiverChanged(address Receiver);
    event UpdatedFeelessAddress(address Address, bool Taxable);
    event Gainz(uint256 amountToCaller, uint256 amountToFloor);
    event MinterAdded(address _address);
    event MinterRenouned(address _address);

    // swapper
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;


    modifier onlyMinter() {
        require(minters[_msgSender()]);
        _;
    }
    
    constructor (uint32 _initFee, uint32 _initDivisor, IUniswapV2Router02 _uniswapV2Router) public ERC20("BANANA", "NANA") {
        //init pair
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        // set the rest
        uniswapV2Router = _uniswapV2Router;
        txFee = _initFee;
        feeDivisor = _initDivisor;
        minters[_msgSender()] = true;
    }

    // burnability
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    //mintability
    function mint(address recipient, uint256 amount) external onlyMinter returns(bool){
        _mint(recipient, amount);
        return true;
    }

    function addMinter(address _newMinter) public onlyOwner {
        minters[_newMinter] = true;
        emit MinterAdded(_newMinter);
    }

    function renounceMinter() public onlyMinter {
        minters[_msgSender()] = false;
        emit MinterRenouned(_msgSender());
    }

    // set the txFee -- via nanas governance staking
    function changeFee(uint32 _newTxFee) public onlyOwner {
        txFee = _newTxFee;
    }

    // enable/disable address to receive fees
    function updateFeelessAddress(address _address, bool _feeless) public onlyOwner {
        feeless[_address] = _feeless;
        emit UpdatedFeelessAddress(_address, _feeless);
    }

    // 
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(sender != address(0), "APE: transfer from the zero address!");
        require(recipient != address(0), "APE: transfer to the zero address!");
        require(amount > 1_000_000, "APE: transferring amount is too small!");

        // check fees and update recipeient balance
        (uint256 transferToAmount, uint256 poolAmount) = calculateAmountsAfterFee(sender, recipient, amount);
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(transferToAmount);
        emit Transfer(sender, recipient, transferToAmount);

        // update distributers balance, if applicable
        if(poolAmount > 0){
            _balances[address(this)] = _balances[address(this)].add(poolAmount);
            emit Transfer(sender, address(this), poolAmount);
        }
    }

    // check fees and return applicable amounts
    function calculateAmountsAfterFee(
        address sender,
        address recipient,
        uint256 amount
    ) private view returns (uint256 transferToAmount, uint256 transferToFeeDistributorAmount) {

        if (feeless[sender] || feeless[recipient]) {
            return (amount, 0);
        }

        uint256 fee = amount.mul(txFee).div(feeDivisor);
        return (amount.sub(fee), fee);
    }

    /* dex functions */

    // call as you plz but beware of gas fees
    function callMeForGainz() public nonReentrant{
        uint256 contractTokenBalance = balanceOf(address(this));
        require(contractTokenBalance >= 1e18, "APE: 1 token plz");

        // 10% to caller
        uint256 amountForCaller = contractTokenBalance.mul(100).div(1000);
        uint256 amountForFloor = contractTokenBalance.sub(amountForCaller);

        // split the contract balance into halves
        uint256 half = amountForFloor.div(2);
        uint256 otherHalf = amountForFloor.sub(half);

        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half);

        uint256 sendMe = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, sendMe);

        // zero out balance on contract
        _balances[address(this)] = 0;
        
        emit Gainz(amountForCaller,amountForFloor);
    }

    //swapper
    function swapTokensForEth(uint256 tokenAmount) private {
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

    // private liquidity added function
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }
}