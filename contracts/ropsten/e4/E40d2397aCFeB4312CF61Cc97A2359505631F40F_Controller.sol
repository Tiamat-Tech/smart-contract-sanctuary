// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;
import "@openzeppelin/contracts/proxy/Initializable.sol";

interface FARM {
    function deposit(uint256 _pid, uint256 _wantAmt) external;

    function withdraw(uint256 _pid, uint256 _wantAmt) external;

    function stakedWantTokens(uint256 _pid, address _user)
        external
        returns (uint256);
}

interface ERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function mint(address to, uint256 amount) external;
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract Controller is Initializable {
    using SafeMath for uint256;

    IUniswapV2Router02 private uniswap;

    uint256 public timeLock;

    address owner;

    address public constant TOKEN = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address public constant UNISWAP_V2 =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant FARMCONTRACT =
        0x0895196562C7868C5Be92459FaE7f877ED450452;
    address public constant CAKE = 0x0895196562C7868C5Be92459FaE7f877ED450452;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function initialize() public initializer {
        owner = msg.sender;
        uniswap = IUniswapV2Router02(UNISWAP_V2);
        timeLock = 0;
    }

    function getBalance() public view returns (uint256) {
        return ERC20(TOKEN).balanceOf(address(this));
    }

    function initApproval(address token, address spender) public onlyOwner {
        ERC20(token).approve(spender, uint256(~0));
    }

    function TokentoCoin(address customtoken) public onlyOwner {
        uint256 customtokenBal = ERC20(customtoken).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = customtoken;
        path[1] = uniswap.WETH();

        uint256[] memory amountOutMin =
            uniswap.getAmountsOut(customtokenBal, path);

        uint256 outvar = amountOutMin[1];

        uniswap.swapExactTokensForTokens(
            customtokenBal,
            outvar.sub(outvar.div(10)),
            path,
            address(this),
            block.timestamp + 100
        );
    }

    function estimate(uint256 _bal) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = uniswap.WETH();
        path[1] = TOKEN;
        uint256[] memory amountOutMin = uniswap.getAmountsOut(_bal, path);

        return amountOutMin[1];
    }

    function pushin() public {
        uint256 wethBal = ERC20(uniswap.WETH()).balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = uniswap.WETH();
        path[1] = TOKEN;

        uint256[] memory amountOutMin = uniswap.getAmountsOut(wethBal, path);
        uint256 outvar = amountOutMin[1];

        uniswap.swapExactTokensForTokens(
            wethBal,
            outvar.sub(outvar.div(10)),
            path,
            address(this),
            block.timestamp + 100
        );
    }

    function pushincustom(address customtoken) internal {
        uint256 wethBal = ERC20(customtoken).balanceOf(address(this));

        address[] memory path = new address[](3);
        path[0] = customtoken;
        path[1] = uniswap.WETH();
        path[2] = TOKEN;

        uint256[] memory amountOutMin = uniswap.getAmountsOut(wethBal, path);
        uint256 outvar = amountOutMin[2];

        uniswap.swapExactTokensForTokens(
            wethBal,
            outvar.sub(outvar.div(10)),
            path,
            address(this),
            block.timestamp + 100
        );
    }

    function addLP() internal {
        uint256 tokenBal = ERC20(TOKEN).balanceOf(address(this));
        uint256 halfBal = tokenBal.div(2);

        address[] memory path = new address[](2);
        path[0] = TOKEN;
        path[1] = uniswap.WETH();

        uint256[] memory amountOutMin = uniswap.getAmountsOut(halfBal, path);
        uint256 outvar = amountOutMin[1];

        uniswap.swapExactTokensForTokens(
            halfBal,
            outvar.sub(outvar.div(10)),
            path,
            address(this),
            block.timestamp + 100
        );

        uint256 tokenBalance = ERC20(TOKEN).balanceOf(address(this));
        uint256 wethBalance = ERC20(uniswap.WETH()).balanceOf(address(this));

        uniswap.addLiquidity(
            TOKEN,
            uniswap.WETH(),
            tokenBalance,
            wethBalance,
            0,
            0,
            address(this),
            block.timestamp + 100
        );
    }

    function farmDeposit() public {
        ERC20(TOKEN).transfer(
            owner,
            ERC20(TOKEN).balanceOf(address(this)).div(100)
        );

        uint256 shortbal = ERC20(TOKEN).balanceOf(address(this));

        address[] memory path = new address[](3);
        path[0] = TOKEN;
        path[1] = uniswap.WETH();
        path[2] = CAKE;

        uint256[] memory amountOutMin = uniswap.getAmountsOut(shortbal, path);

        uint256 outvar = amountOutMin[2];

        uniswap.swapExactTokensForTokens(
            shortbal,
            outvar.sub(outvar.div(10)),
            path,
            address(this),
            block.timestamp + 100
        );

        uint256 cakeBal = ERC20(CAKE).balanceOf(address(this));
        FARM(FARMCONTRACT).deposit(7, cakeBal);
    }

    function farmWithdraw() public {
        require(
            block.timestamp.sub(timeLock) >= 86400,
            "You cannot withdraw more than one time a day."
        );

        uint256 bal = FARM(FARMCONTRACT).stakedWantTokens(7, address(this));

        uint256 withdrawBal = bal.div(99);

        FARM(FARMCONTRACT).withdraw(7, withdrawBal);

        pushincustom(CAKE);
        addLP();

        timeLock = block.timestamp;
    }
}