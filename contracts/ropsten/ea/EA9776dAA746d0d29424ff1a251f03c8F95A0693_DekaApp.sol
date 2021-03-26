// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "./interfaces/IERC20.sol";
import "./interfaces/IDekaReceiver.sol";
import "./interfaces/IDekaReceiver.sol";
import "./interfaces/IDekaProtocol.sol";

import "./libraries/SafeMath.sol";
import "./libraries/Address.sol";
import "./libraries/Create2.sol";
import "./libraries/SafeERC20.sol";

import "./pool/contracts/Pool.sol";

contract DekaApp is IDekaReceiver {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant DEKA_TOKEN = 0x992d63281EbF61061fd79623F294d0F0296BeF81; // CONFIG: Current Address (deka.finance.token)
    address public constant DEKA_PROTOCOL = 0x88629f11e22861043B2E701207a19Aeb743562F9; // CONFIG: Current Address (deka.finance.protocol)

    mapping(bytes32 => uint256) public stakerReward;
    mapping(address => address) public pools; // token -> pools

    event PoolCreated(address _pool, address _token);

    event Staked(bytes32 _id, uint256 _rewardAmount, address _pool);

    event LiquidityAdded(address _pool, uint256 _amountDEKA, uint256 _amountALT, uint256 _liquidity, address _sender);

    event LiquidityRemoved(address _pool, uint256 _amountDEKA, uint256 _amountALT, uint256 _liquidity, address _sender);

    event Swapped(address _sender, uint256 _swapAmount, uint256 _dekaReceived, address _pool);

    modifier onlyProtocol() {
        require(msg.sender == DEKA_PROTOCOL, "DekaApp:: ONLY_PROTOCOL");
        _;
    }

    function createPool(address _token) external returns (address poolAddress) {
        require(_token != address(0), "DekaApp:: INVALID_TOKEN_ADDRESS");
        require(pools[_token] == address(0), "DekaApp:: POOL_ALREADY_EXISTS");
        bytes memory bytecode = type(Pool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, msg.sender));
        poolAddress = Create2.deploy(0, salt, bytecode);
        pools[_token] = poolAddress;
        IPool(poolAddress).initialize(_token);
        emit PoolCreated(poolAddress, _token);
    }

    function receiveDeka(
        bytes32 _id,
        uint256 _amountIn, //unused
        uint256 _expireAfter, //unused
        uint256 _mintedAmount,
        address _staker,
        bytes calldata _data
    ) external override onlyProtocol returns (uint256) {
        (address token, uint256 expectedOutput) = abi.decode(_data, (address, uint256));
        address pool = pools[token];
        IERC20(DEKA_TOKEN).safeTransfer(pool, _mintedAmount);
        uint256 reward = IPool(pool).stakeWithFeeRewardDistribution(_mintedAmount, _staker, expectedOutput);
        stakerReward[_id] = reward;
        emit Staked(_id, reward, pool);
    }

    function unstake(bytes32[] memory _expiredIds) public {
        for (uint256 i = 0; i < _expiredIds.length; i = i.add(1)) {
            IDekaProtocol(DEKA_PROTOCOL).unstake(_expiredIds[i]);
        }
    }

    function swap(
        uint256 _altQuantity,
        address _token,
        uint256 _expectedOutput
    ) public returns (uint256 result) {
        address user = msg.sender;
        address pool = pools[_token];

        require(pool != address(0), "DekaApp:: POOL_DOESNT_EXIST");
        require(_altQuantity > 0, "DekaApp:: INVALID_AMOUNT");

        IERC20(_token).safeTransferFrom(user, address(this), _altQuantity);
        IERC20(_token).safeTransfer(pool, _altQuantity);

        result = IPool(pool).swapWithFeeRewardDistribution(_altQuantity, user, _expectedOutput);

        emit Swapped(user, _altQuantity, result, pool);
    }

    function addLiquidityInPool(
        uint256 _amountDEKA,
        uint256 _amountALT,
        uint256 _amountDEKAMin,
        uint256 _amountALTMin,
        address _token
    ) public {
        address maker = msg.sender;
        address pool = pools[_token];

        require(pool != address(0), "DekaApp:: POOL_DOESNT_EXIST");
        require(_amountDEKA > 0 && _amountALT > 0, "DekaApp:: INVALID_AMOUNT");

        (uint256 amountDEKA, uint256 amountALT, uint256 liquidity) = IPool(pool).addLiquidity(
            _amountDEKA,
            _amountALT,
            _amountDEKAMin,
            _amountALTMin,
            maker
        );

        IERC20(DEKA_TOKEN).safeTransferFrom(maker, address(this), amountDEKA);
        IERC20(DEKA_TOKEN).safeTransfer(pool, amountDEKA);

        IERC20(_token).safeTransferFrom(maker, address(this), amountALT);
        IERC20(_token).safeTransfer(pool, amountALT);

        emit LiquidityAdded(pool, amountDEKA, amountALT, liquidity, maker);
    }

    function removeLiquidityInPool(uint256 _liquidity, address _token) public {
        address maker = msg.sender;

        address pool = pools[_token];

        require(pool != address(0), "DekaApp:: POOL_DOESNT_EXIST");

        IERC20(pool).safeTransferFrom(maker, address(this), _liquidity);
        IERC20(pool).safeTransfer(pool, _liquidity);

        (uint256 amountDEKA, uint256 amountALT) = IPool(pool).removeLiquidity(maker);

        emit LiquidityRemoved(pool, amountDEKA, amountALT, _liquidity, maker);
    }

    function removeLiquidityInPoolWithPermit(
        uint256 _liquidity,
        address _token,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public {
        address maker = msg.sender;

        address pool = pools[_token];

        require(pool != address(0), "DekaApp:: POOL_DOESNT_EXIST");

        IERC20(pool).permit(maker, pool, type(uint256).max, _deadline, _v, _r, _s);

        IERC20(pool).safeTransferFrom(maker, pool, _liquidity);

        (uint256 amountDEKA, uint256 amountALT) = IPool(pool).removeLiquidity(maker);

        emit LiquidityRemoved(pool, amountDEKA, amountALT, _liquidity, maker);
    }
}