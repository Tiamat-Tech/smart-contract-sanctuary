// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IExchangeWithAtomic.sol";
import "./interfaces/IOrionMigratorToAtomic.sol";
import "./interfaces/IWETH9.sol";


contract OrionMigratorToAtomic is IOrionMigratorToAtomic, Ownable {
    using SafeERC20 for IERC20;

    IExchangeWithAtomic public exchange;
    IWETH9 public WETH9;
    bool initialized;

    /**
     * @notice Can only be called once
     * @dev Initalizes parameters of the migrator contract
     * @param _exchange address of the exchange
     * @param _WETH9 address of the native token
     */
    function initialize (address _exchange, address _WETH9) external onlyOwner {
        require(!initialized, "Already initialized");
        exchange = IExchangeWithAtomic(_exchange);
        WETH9 = IWETH9(_WETH9);
        initialized = true;
    }

    receive() external payable {
        require(msg.sender == address(WETH9));
    }

    /**
     * @notice  !!!Important!!! Before calling, one must make sure that lockOrderDetails0 is for token0 and lockOrderDetails is for token1.
     *          This can be checked by calling the pair contract with the functions token0() and token1() accordingly    
     * @dev Migrates token/tokens from the token-token pair pool to the exchange and locks token/tokens atomically   
     * @param _pair address of the token-token pair pool
     * @param tokensToMigrate number of LP tokens of the token-token pair pool to migrate
     * @param _lockOrderDetails0 atomic details for the token0
     * @param _lockOrderDetails1 atomic details for the token1
     *  struct LockOrderDetails{
     *      bool toLockInAtomic;
     *      uint64 expiration;
     *      bytes32 secretHash;
     *      bool used;        
     *   }
     * where toLockInAtomic is bool, if true migrates the token and locks in the atomic, if false - returns to the user
     * where expiration, secretHash, used - atomic details
     */
    function migrate(address _pair, uint256 tokensToMigrate, LockOrderDetails memory _lockOrderDetails0, LockOrderDetails memory _lockOrderDetails1) external override {

        IUniswapV2Pair uniswapPair;
        uniswapPair = IUniswapV2Pair(_pair);
        IERC20 token0;
        IERC20 token1;
        token0 = IERC20(IUniswapV2Pair(_pair).token0());
        token1 = IERC20(IUniswapV2Pair(_pair).token1());

        require(uniswapPair.transferFrom(msg.sender, address(uniswapPair), tokensToMigrate), 'TRANSFER_FROM_FAILED');

        (uint256 amount0V1, uint256 amount1V1) = uniswapPair.burn(address(this));

        if(_lockOrderDetails0.toLockInAtomic == true){
            token0.safeApprove(address(exchange), amount0V1);
            exchange.lockAtomic(IExchangeWithAtomic.LockOrder(msg.sender, address(token0), uint64(amount0V1), _lockOrderDetails0.expiration, _lockOrderDetails0.secretHash, _lockOrderDetails0.used));
        } else {
            if (address(token0) == address(WETH9)) {
                WETH9.withdraw(amount0V1);
                msg.sender.transfer(amount0V1);
            } else {
                token0.safeTransfer(msg.sender, amount0V1);
            }            
        }

        if(_lockOrderDetails1.toLockInAtomic == true){
            token1.safeApprove(address(exchange), amount1V1);
            exchange.lockAtomic(IExchangeWithAtomic.LockOrder(msg.sender, address(token1), uint64(amount1V1), _lockOrderDetails1.expiration, _lockOrderDetails1.secretHash, _lockOrderDetails1.used));
        } else {
            if (address(token1) == address(WETH9)) {
                WETH9.withdraw(amount1V1);
                msg.sender.transfer(amount1V1);
            } else {
                token0.safeTransfer(msg.sender, amount1V1);
            }            
        }

    }

}