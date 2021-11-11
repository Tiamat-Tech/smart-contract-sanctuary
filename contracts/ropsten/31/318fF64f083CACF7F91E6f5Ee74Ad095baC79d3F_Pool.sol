// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
pragma abicoder v2;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import './libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';



contract Pool is IERC721Receiver{
   
    struct Deposit {
        address owner;
        uint liquidity;
        address tokenA;
        address tokenB;
        uint amountA;
        uint amountB;
    }

    IUniswapV3Factory public uniswapFactory;
    INonfungiblePositionManager public nonfungiblePositionManager;
    mapping(uint256 => Deposit) public deposits;
    mapping(address => uint[]) public poolToDeposits;

    constructor(
        address _uniswapFactory,
        address _nonfungiblePositionManager) {
        uniswapFactory = IUniswapV3Factory(_uniswapFactory);
        nonfungiblePositionManager = INonfungiblePositionManager(_nonfungiblePositionManager);
    }

    function createPool(
        address _tokenA, 
        address _tokenB, 
        uint24 _fee,
        uint160 _price) external returns(address pool)
    {
        pool = uniswapFactory.createPool(_tokenA, _tokenB, _fee);
        IUniswapV3Pool(pool).initialize(_price);
    }

    function  getPoolAddress(
        address _tokenA, 
        address _tokenB, 
        uint24 _fee) external view returns(address pool)
    {
        pool =  PoolAddress.computeAddress(
            address(uniswapFactory), 
            PoolAddress.getPoolKey(_tokenA, _tokenB, _fee));
    }

    function mintNewPosition(
        address _tokenA, 
        address _tokenB, 
        uint24 _fee,
        uint amountA,
        uint amountB
    )
        external
    {
        TransferHelper.safeTransferFrom(_tokenA, msg.sender, address(this), amountA);
        TransferHelper.safeTransferFrom(_tokenB, msg.sender, address(this), amountB);

        TransferHelper.safeApprove(_tokenA, address(nonfungiblePositionManager), amountA);
        TransferHelper.safeApprove(_tokenB, address(nonfungiblePositionManager), amountB);
        
        // slippage 1%
        uint amountAMin = amountA*(1e3) - (amountA*(1e3)) / (1e2);
        uint amountBMin = amountB*(1e3) - (amountB*(1e3)) / (1e2);

        INonfungiblePositionManager.MintParams memory params =
            INonfungiblePositionManager.MintParams({
                token0: _tokenA,
                token1: _tokenB,
                fee: _fee,
                tickLower: TickMath.MIN_TICK,
                tickUpper: TickMath.MAX_TICK,
                amount0Desired: amountA,
                amount1Desired: amountB,
                amount0Min: amountAMin/(1e3),
                amount1Min: amountBMin/(1e3),
                recipient: address(this),
                deadline: block.timestamp + 120
            });

        // (uint tokenId, uint liquidity, uint amount0, uint amount1) = nonfungiblePositionManager.mint(params);
        // deposits[tokenId] = Deposit(
        //     msg.sender, 
        //     liquidity,
        //     _tokenA,
        //     _tokenB,
        //     amount0,
        //     amount1);

        // address pool =  PoolAddress.computeAddress(
        //     address(uniswapFactory), 
        //     PoolAddress.getPoolKey(_tokenA, _tokenB, _fee));
        // poolToDeposits[pool].push(tokenId);
    
        // if (amount0 < amountA) {
        //     TransferHelper.safeApprove(_tokenA, address(nonfungiblePositionManager), 0);
        //     TransferHelper.safeTransfer(_tokenA, msg.sender, amountA - amount0);
        // }

        // if (amount1 < amountB) {
        //     TransferHelper.safeApprove(_tokenB, address(nonfungiblePositionManager), 0);
        //     TransferHelper.safeTransfer(_tokenB, msg.sender, amountB - amount1);
        // }

    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}