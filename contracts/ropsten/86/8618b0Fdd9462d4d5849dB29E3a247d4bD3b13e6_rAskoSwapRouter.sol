pragma solidity =0.6.6;

import "@pancakeswap-libs/pancake-swap-core/contracts/interfaces/IPancakeFactory.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "./rAskoSwapLibrary.sol";
import "./interfaces/IrAskoSwapRouter.sol";
//import '@theanthill/pancake-swap-periphery/contracts/interfaces/IPancakeRouter01.sol';
import "@theanthill/pancake-swap-periphery/contracts/interfaces/IERC20.sol";

import "hardhat/console.sol";

contract rAskoSwapRouter is IrAskoSwapRouter {
    address public immutable override factory;

    // fee to be taken out of swaps, 1000 = 100%, 10 = 1%
    uint256 LPFee;

    uint256 DAOFee;
    address DAOAddress;

    uint256 OperatingFee;
    address OperatingAddress;

    uint256 BuybackFee;
    address BuybackAddress;

    address public admin;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "rAskoSwapRouter: EXPIRED");
        _;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == admin,
            "rAskoSwapRouter: ONLY THE ADMIN CAN USE THIS FUNCTION"
        );
        _;
    }

    constructor(
        address _factory,
        uint256 _LPFee,
        uint256 _DAOFee,
        address _DAOAddress,
        uint256 _OperatingFee,
        address _OperatingAddress,
        uint256 _BuybackFee,
        address _BuybackAddress
    ) public {
        factory = _factory;
        LPFee = _LPFee;
        DAOFee = _DAOFee;
        DAOAddress = _DAOAddress;
        OperatingFee = _OperatingFee;
        OperatingAddress = _OperatingAddress;
        BuybackFee = _BuybackFee;
        BuybackAddress = _BuybackAddress;
        admin = msg.sender;
    }

    function changeAdmin(address newAdmin) public onlyAdmin {
        admin = newAdmin;
    }

    function changeLPFee(uint256 newFee) public onlyAdmin {
        require(newFee < 1000, "rAskoSwapRouter: LPFEE MUST BE BELOW 100%");
        LPFee = newFee;
    }

    function changeDAOFee(uint256 newFee) public onlyAdmin {
        require(newFee + OperatingFee + BuybackFee < 1000, "rAskoSwapRouter: Total FEE MUST BE BELOW 100%");
        DAOFee = newFee;
    }

    function changeOperatingFee(uint256 newFee) public onlyAdmin {
        require(newFee + DAOFee + BuybackFee < 1000, "rAskoSwapRouter: Total FEE MUST BE BELOW 100%");
        OperatingFee = newFee;
    }

    function changeBuybackFee(uint256 newFee) public onlyAdmin {
        require(newFee + DAOFee + OperatingFee < 1000, "rAskoSwapRouter: Total FEE MUST BE BELOW 100%");
        BuybackFee = newFee;
    }

    function checkPairFor(address token1, address token2)
        public
        view
        returns (address ret)
    {
        ret = rAskoSwapLibrary.pairFor(factory, token1, token2);
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) private returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IPancakeFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IPancakeFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = rAskoSwapLibrary.getReserves(
            factory,
            tokenA,
            tokenB
        );
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = rAskoSwapLibrary.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "rAskoSwapRouter: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = rAskoSwapLibrary.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    "rAskoSwapRouter: INSUFFICIENT_A_AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

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
        override
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pair = rAskoSwapLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IPancakePair(pair).mint(to);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        public
        override
        ensure(deadline)
        returns (uint256 amountA, uint256 amountB)
    {
        address pair = rAskoSwapLibrary.pairFor(factory, tokenA, tokenB);
        IPancakePair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IPancakePair(pair).burn(to);
        (address token0, ) = rAskoSwapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);
        require(
            amountA >= amountAMin,
            "rAskoSwapRouter: INSUFFICIENT_A_AMOUNT"
        );
        require(
            amountB >= amountBMin,
            "rAskoSwapRouter: INSUFFICIENT_B_AMOUNT"
        );
    }

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
    ) external override returns (uint256 amountA, uint256 amountB) {
        address pair = rAskoSwapLibrary.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IPancakePair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountA, amountB) = removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) private {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = rAskoSwapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? rAskoSwapLibrary.pairFor(factory, output, path[i + 2])
                : _to;
            IPancakePair(rAskoSwapLibrary.pairFor(factory, input, output)).swap(
                    amount0Out,
                    amount1Out,
                    to,
                    new bytes(0)
                );
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        // calculate fees
        uint256 DAORemainder = (amountIn * DAOFee) / 1000;
        uint256 OperatingRemainder = (amountIn * OperatingFee) / 1000;
        uint256 BuybackRemainder = (amountIn * BuybackFee) / 1000;

        TransferHelper.safeTransferFrom(path[0], msg.sender, DAOAddress, DAORemainder);
        TransferHelper.safeTransferFrom(path[0], msg.sender, OperatingAddress, OperatingRemainder);
        TransferHelper.safeTransferFrom(path[0], msg.sender, BuybackAddress, BuybackRemainder);

        uint256 amountInWithFee = amountIn - DAORemainder - OperatingRemainder - BuybackRemainder;

        amounts = rAskoSwapLibrary.getAmountsOut(
            factory,
            amountInWithFee,
            path,
            LPFee
        );
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "rAskoSwapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            rAskoSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = rAskoSwapLibrary.getAmountsIn(
            factory,
            amountOut,
            path,
            LPFee
        );

        // require user inputs more tokens, LPFee already taken, now take rest of fees from amount[0]
        uint256 fullAmountIn = ((amounts[0] *
            1000) / (1000 - (DAOFee + OperatingFee + BuybackFee)));
        console.log(fullAmountIn, amounts[0]);

        require(
            fullAmountIn <= amountInMax,
            "rAskoSwapRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            rAskoSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        ); // Transfer amounts[0] to pair for the swap
        _swap(amounts, path, to);

        // Use remainder of tokens to send to fee collectors
        uint256 DAORemainder = (fullAmountIn * DAOFee) / 1000;
        uint256 OperatingRemainder = (fullAmountIn * OperatingFee) / 1000;
        uint256 BuybackRemainder = (fullAmountIn * BuybackFee) / 1000;

        TransferHelper.safeTransferFrom(path[0], msg.sender, DAOAddress, DAORemainder);
        TransferHelper.safeTransferFrom(path[0], msg.sender, OperatingAddress, OperatingRemainder);
        TransferHelper.safeTransferFrom(path[0], msg.sender, BuybackAddress, BuybackRemainder);
    }

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure override returns (uint256 amountB) {
        return rAskoSwapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public view override returns (uint256 amountOut) {
        return
            rAskoSwapLibrary.getAmountOut(
                amountIn,
                reserveIn,
                reserveOut,
                LPFee
            );
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public view override returns (uint256 amountIn) {
        return
            rAskoSwapLibrary.getAmountIn(
                amountOut,
                reserveIn,
                reserveOut,
                LPFee
            );
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        override
        returns (uint256[] memory amounts)
    {
        return rAskoSwapLibrary.getAmountsOut(factory, amountIn, path, LPFee);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        override
        returns (uint256[] memory amounts)
    {
        return rAskoSwapLibrary.getAmountsIn(factory, amountOut, path, LPFee);
    }
}