// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IFuzzyswapFactory.sol';
import './interfaces/IFuzzyswapPoolDeployer.sol';
import './interfaces/IExternalOracle.sol';

import './ExternalOracle.sol';

/// @title Canonical Fuzzyswap factory
/// @notice Deploys Fuzzyswap pools and manages ownership and control over pool protocol fees
contract FuzzyswapFactory is IFuzzyswapFactory {
    /// @inheritdoc IFuzzyswapFactory
    address public override owner;

    /// @inheritdoc IFuzzyswapFactory
    address public override poolDeployer;

    /// @inheritdoc IFuzzyswapFactory
    address public override stackerAddress;

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    /// @inheritdoc IFuzzyswapFactory
    mapping(address => mapping(address => address)) public override getPool;

    constructor(address _poolDeployer) {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);

        poolDeployer = _poolDeployer;
    }

    /// @inheritdoc IFuzzyswapFactory
    function createPool(
        address tokenA,
        address tokenB
    ) external override returns (address pool) {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        require(getPool[token0][token1] == address(0));

        IExternalOracle oracle = IExternalOracle(address(new ExternalOracle()));

        pool = IFuzzyswapPoolDeployer(poolDeployer).deploy(address(oracle), address(this), token0, token1);

        oracle.setPool(address(pool));
        getPool[token0][token1] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0] = pool;
        emit PoolCreated(token0, token1, pool);
    }

    /// @inheritdoc IFuzzyswapFactory
    function setOwner(address _owner) external onlyOwner override {
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @inheritdoc IFuzzyswapFactory
    function setStackerAddress(address _stackerAddress) external onlyOwner override {
        stackerAddress = _stackerAddress;
    }
}