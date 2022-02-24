//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./compound/ICERC20.sol";
import "./compound/ICEther.sol";
import "./compound/IComptroller.sol";
import "./uniswap/IUniswapV2Pair.sol";
import "./uniswap/IUniswapV2Router.sol";
import "./uniswap/IUniswapV2Factory.sol";
import "hardhat/console.sol";

interface IWETH9 {
    function deposit() external payable;
}
contract CompoundLiquidations {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address private _owner;

    // mainnet
    //address internal constant COMPTROLLER_ADDRESS = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    //address internal constant UNISWAP_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    //address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    //address internal constant CETH_ADDRESS = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    //address internal constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // ropsten
    address internal constant COMPTROLLER_ADDRESS = 0xcfa7b0e37f5AC60f3ae25226F5e39ec59AD26152;
    address internal constant UNISWAP_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant CETH_ADDRESS = 0x859e9d8a4edadfEDb5A2fF311243af80F85A91b8;
    address internal constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    IComptroller constant public Comptroller = IComptroller(COMPTROLLER_ADDRESS);
    IUniswapV2Factory constant public FACTORY = IUniswapV2Factory(UNISWAP_FACTORY_ADDRESS);
    IUniswapV2Router constant public ROUTER = IUniswapV2Router(UNISWAP_ROUTER_ADDRESS);
    address constant public WETH = address(WETH_ADDRESS);
    address constant public cETH = address(CETH_ADDRESS);

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor() public {
        address msgSender = msg.sender;
        _owner = msgSender;
    }

    function owner() public view returns (address) {
        return _owner;
    }


    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function pairFor(address borrowed) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(borrowed, WETH);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                FACTORY,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            )))));
    }

    // 清算
    function liquidate(address borrower, address borrowed, address supplied) external onlyOwner {
        // 判断是否可被清算
        console.log("1");
        (,,uint256 shortFall) = Comptroller.getAccountLiquidity(borrower);
        require(shortFall > 0, "liquidate:shortFall == 0");

        console.log("2 %s", shortFall);
        // 判断借款金额
        uint256 amount = ICERC20(borrowed).borrowBalanceStored(borrower);
        require(amount > 0, "liquidate:borrowBalanceStored == 0");

        console.log("3 %s", amount);
        // 判断清算金额
        amount = amount.mul(Comptroller.closeFactorMantissa()).div(1e18);
        require(amount > 0, "liquidate:liquidatableAmount == 0");
        console.log("4 %s", amount);

        // 清算
        // 借款为ETH的情况
        if (borrowed == CETH_ADDRESS) {
            console.log("5");
        } else {
            console.log("6");
            uint256 liquidatableAmount = amount;
            // 借款的原生token
            address borrowedUnderlying = ICERC20(borrowed).underlying();
            console.log("7 %s", borrowedUnderlying);
            // 批准借款ctoken转移原生token用于清算
            IERC20(borrowedUnderlying).approve(
                borrowed,
                liquidatableAmount
            );
            console.log("8");
            uint256 allowance = IERC20(borrowedUnderlying).allowance(
                address(this),
                borrower
            );
            console.log("9 %s", allowance);
            ICERC20(borrowed).liquidateBorrow(borrower, liquidatableAmount, supplied);
            console.log("10");
        }

        console.log("11");
        // 处理奖励
        //ICERC20(supplied).redeem(ICERC20(supplied).balanceOf(address(this)));
        IERC20(supplied).transfer(address(_owner), IERC20(supplied).balanceOf(address(this)));
        console.log("12");



        //liquidateCalculated(borrower, borrowed, supplied, fromPair, toPair, borrowedUnderlying, suppliedUnderlying, amount);
    }

    function withdrawEth() external onlyOwner {
        (bool success, ) = msg.sender.call{ value: address(this).balance }("");
        require(success, "Withdraw failed.");
    }

    function withdrawToken(address tokenAddress, uint256 amount)
        external
        onlyOwner
    {
        if (amount == uint256(0)) {
            IERC20(tokenAddress).transfer(address(_owner), IERC20(tokenAddress).balanceOf(address(this)));
        } else {
            IERC20(tokenAddress).transfer(address(_owner), amount);
        }
    }

    receive() external payable { }
}