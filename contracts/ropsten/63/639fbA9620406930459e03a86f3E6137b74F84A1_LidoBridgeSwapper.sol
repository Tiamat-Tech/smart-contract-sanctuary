//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.3;

import "./ZkSyncBridgeSwapper.sol";
import "./interfaces/IZkSync.sol";
import "./interfaces/IWstETH.sol";
import "./interfaces/ILido.sol";
import "./interfaces/ICurvePool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
* Exchanges between ETH and wStETH
* index 0: ETH
* index 1: wStETH
*/
contract LidoBridgeSwapper is ZkSyncBridgeSwapper {

    // The address of the stEth token
    address public immutable stEth;
    // The address of the wrapped stEth token
    address public immutable wStEth;
    // The address of the stEth/Eth Curve pool
    address public immutable stEthPool;
    // The referral address for Lido
    address public immutable lidoReferral;

    constructor(
        address _zkSync,
        address _l2Account,
        address _wStEth,
        address _stEthPool,
        address _lidoReferral
    ) ZkSyncBridgeSwapper(_zkSync, _l2Account) {
        wStEth = _wStEth;
        stEth = IWstETH(_wStEth).stETH();
        stEthPool = _stEthPool;
        lidoReferral =_lidoReferral;
    }

    function exchange(uint256 _indexIn, uint256 _indexOut, uint256 _amountIn) external override returns (uint256 amountOut) {
        if (_indexIn == 0) {
            require(_indexOut == 1, "Invalid bought coin");
            return swapEthForStEth(_amountIn);
        }
        if (_indexIn == 1) {
            require(_indexOut == 0, "Invalid bought coin");
            return swapStEthForEth(_amountIn);
        }
        revert("Invalid sold coin");
    }

    /**
    * @dev Swaps ETH for wrapped stETH and deposits the resulting wstETH to the ZkSync bridge.
    * First withdraws ETH from the bridge if there is a pending balance.
    * @param _amountIn The amount of ETH to swap.
    */
    function swapEthForStEth(uint256 _amountIn) internal returns (uint256) {
        transferZKSyncBalance(ETH_TOKEN);
        // swap Eth for stEth on the Lido contract
        ILido(stEth).submit{value: _amountIn}(lidoReferral);
        // approve the wStEth contract to take the stEth
        IERC20(stEth).approve(wStEth, _amountIn);
        // wrap to wStEth
        uint256 amountOut = IWstETH(wStEth).wrap(_amountIn);
        // approve the zkSync bridge to take the wrapped stEth
        IERC20(wStEth).approve(zkSync, amountOut);
        // deposit the wStEth to the L2 bridge
        IZkSync(zkSync).depositERC20(IERC20(wStEth), toUint104(amountOut), l2Account);
        // emit event
        emit Swapped(ETH_TOKEN, _amountIn, wStEth, amountOut);
        // return deposited amount
        return amountOut;
    }

    /**
    * @dev Swaps wrapped stETH for ETH and deposits the resulting ETH to the ZkSync bridge.
    * First withdraws wrapped stETH from the bridge if there is a pending balance.
    * @param _amountIn The amount of wrapped stETH to swap.
    */
    function swapStEthForEth(uint256 _amountIn) internal returns (uint256) {
        transferZKSyncBalance(wStEth);
        // unwrap to stEth
        uint256 unwrapped = IWstETH(wStEth).unwrap(_amountIn);
        // approve pool
        bool success = IERC20(stEth).approve(stEthPool, unwrapped);
        require(success, "approve failed");
        // swap stEth for ETH on Curve
        uint256 amountOut = ICurvePool(stEthPool).exchange(1, 0, unwrapped, getMinAmountOut(unwrapped));
        // deposit Eth to L2 bridge
        IZkSync(zkSync).depositETH{value: amountOut}(l2Account);
        // emit event
        emit Swapped(wStEth, _amountIn, ETH_TOKEN, amountOut);
        // return deposited amount
        return amountOut;
    }
}