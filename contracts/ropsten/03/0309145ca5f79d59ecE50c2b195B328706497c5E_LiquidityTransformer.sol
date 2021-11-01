// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "./libs/SafeERC20.sol";
import "./libs/Ownable.sol";

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

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

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {}

interface IUniswapV2Pair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

contract LiquidityTransformer {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    IERC20 public lendflareToken;
    IUniswapV2Pair public uniswapPair;

    IUniswapV2Router02 public constant uniswapRouter =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    address payable constant teamAddress =
        0x0779Cfc15116283792698Da362F9ACBd1C4b8abf;

    uint256 public constant liquifyTokens = 200 * 1e18;
    uint256 constant investmentDays = 7 days;
    uint256 constant minInvest = 0.1 ether;
    uint256 public startedAt;

    struct Globals {
        uint256 totalUsers;
        uint256 transferedUsers;
        uint256 totalWeiContributed;
        bool liquidity;
    }

    Globals public globals;

    mapping(address => uint256) public investorBalances;
    mapping(address => uint256[2]) investorHistory;

    event UniSwapResult(
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    );

    modifier afterUniswapTransfer() {
        require(globals.liquidity == true, "forward liquidity first");
        _;
    }

    receive() external payable {
        revert();
    }

    constructor(address _lendflareToken) public {
        lendflareToken = IERC20(_lendflareToken);
        startedAt = block.timestamp;
        // UNISWAPPAIR = UniswapV2Pair(_uniswapPair);
    }

    function createPair() external {
        uniswapPair = IUniswapV2Pair(
            IUniswapV2Factory(factory()).createPair(WETH(), address(this))
        );
    }

    function reserve() external payable {
        require(msg.value >= minInvest, "investment below minimum");

        _reserve(msg.sender, msg.value);
    }

    function reserveWithToken(address _tokenAddress, uint256 _tokenAmount)
        external
    {
        IERC20 token = IERC20(_tokenAddress);

        token.transferFrom(msg.sender, address(this), _tokenAmount);

        token.approve(address(uniswapRouter), _tokenAmount);

        address[] memory _path = preparePath(_tokenAddress);

        uint256[] memory amounts = uniswapRouter.swapExactTokensForETH(
            _tokenAmount,
            0,
            _path,
            address(this),
            block.timestamp.add(2 hours)
        );

        require(amounts[1] >= minInvest, "investment below minimum");

        _reserve(msg.sender, amounts[1]);
    }

    function _reserve(address _senderAddress, uint256 _senderValue) internal {
        investorBalances[_senderAddress] += _senderValue;

        globals.totalWeiContributed += _senderValue;
        globals.totalUsers++;
    }

    function forwardLiquidity() external {
        require(
            block.timestamp >= startedAt.add(investmentDays),
            "Not over yet"
        );

        uint256 _fee = globals.totalWeiContributed.mul(100).div(1000);
        uint256 _balance = globals.totalWeiContributed.sub(_fee);

        teamAddress.transfer(_fee);

        uint256 half = liquifyTokens.div(2);

        lendflareToken.approve(address(uniswapRouter), half);

        (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        ) = uniswapRouter.addLiquidityETH{value: _balance}(
                address(lendflareToken),
                half,
                0,
                0,
                address(0x0),
                block.timestamp.add(2 hours)
            );

        globals.liquidity = true;

        emit UniSwapResult(amountToken, amountETH, liquidity);
    }

    function getMyTokens() external afterUniswapTransfer {
        require(investorBalances[msg.sender] > 0, "!balance");

        // uint256 tokenBalance = IERC20(lendflareToken).balanceOf(address(this));
        uint256 half = liquifyTokens.div(2);
        uint256 otherHalf = liquifyTokens.sub(half);
        uint256 percent = investorBalances[msg.sender].mul(100e18).div(
            globals.totalWeiContributed
        );
        uint256 myTokens = otherHalf.mul(percent).div(100e18);

        investorHistory[msg.sender][0] = investorBalances[msg.sender];
        investorHistory[msg.sender][1] = myTokens;
        investorBalances[msg.sender] = 0;

        IERC20(lendflareToken).safeTransfer(msg.sender, myTokens);

        globals.transferedUsers++;

        if (globals.transferedUsers == globals.totalUsers) {
            uint256 surplusBalance = IERC20(lendflareToken).balanceOf(
                address(this)
            );

            if (surplusBalance > 0) {
                IERC20(lendflareToken).safeTransfer(
                    0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
                    surplusBalance
                );
            }
        }
    }

    /* view functions */
    function WETH() public pure returns (address) {
        return IUniswapV2Router02(uniswapRouter).WETH();
    }

    function factory() public pure returns (address) {
        return IUniswapV2Router02(uniswapRouter).factory();
    }

    function getInvestorHistory(address _sender)
        public
        view
        returns (uint256[2] memory)
    {
        return investorHistory[_sender];
    }

    function preparePath(address _tokenAddress)
        internal
        pure
        returns (address[] memory _path)
    {
        _path = new address[](2);
        _path[0] = _tokenAddress;
        _path[1] = WETH();
    }
}