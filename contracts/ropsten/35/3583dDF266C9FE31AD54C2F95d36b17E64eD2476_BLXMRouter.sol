// SPDX-License-Identifier: GPL-3.0 License

pragma solidity ^0.8.0;

import "./BLXMRewardProvider.sol";
import "./interfaces/IBLXMRouter.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interfaces/IWETH.sol";

import "./libraries/TransferHelper.sol";
import "./libraries/BLXMLibrary.sol";


contract BLXMRouter is Initializable, BLXMRewardProvider, IBLXMRouter {

    address public override BLXM;
    address public override WETH;


    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'EXPIRED');
        _;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH/BNB via fallback from the WETH contract
    }

    function initialize(address _BLXM, address _WETH) public initializer {
        __ReentrancyGuard_init();
        __BLXMMultiOwnable_init();
        BLXM = _BLXM;
        WETH = _WETH;
    }

    function addRewards(address token, uint amountBlxm) external override returns (uint amountPerDays) {
        address treasury = getTreasury(token);
        TransferHelper.safeTransferFrom(BLXM, msg.sender, treasury, amountBlxm);
        return _addRewards(token, amountBlxm);
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address token,
        uint amountBlxmDesired,
        uint amountTokenDesired,
        uint amountBlxmMin,
        uint amountTokenMin
    ) private view returns (uint amountBlxm, uint amountToken) {
        (uint reserveBlxm, uint reserveToken) = getReserves(token);
        if (reserveBlxm == 0 && reserveToken == 0) {
            (amountBlxm, amountToken) = (amountBlxmDesired, amountTokenDesired);
        } else {
            uint amountTokenOptimal = quote(amountBlxmDesired, reserveBlxm, reserveToken);
            if (amountTokenOptimal <= amountTokenDesired) {
                require(amountTokenOptimal >= amountTokenMin, 'INSUFFICIENT_BLXM_AMOUNT');
                (amountBlxm, amountToken) = (amountBlxmDesired, amountTokenOptimal);
            } else {
                uint amountBlxmOptimal = quote(amountTokenDesired, reserveToken, reserveBlxm);
                assert(amountBlxmOptimal <= amountBlxmDesired);
                require(amountBlxmOptimal >= amountBlxmMin, 'INSUFFICIENT_TOKEN_AMOUNT');
                (amountBlxm, amountToken) = (amountBlxmOptimal, amountTokenDesired);
            }
        }
    }

    function addLiquidity(
        address token,
        uint amountBlxmDesired,
        uint amountTokenDesired,
        uint amountBlxmMin,
        uint amountTokenMin,
        address to,
        uint deadline,
        uint16 lockedDays
    ) external override ensure(deadline) returns (uint amountBlxm, uint amountToken, uint liquidity) {
        (amountBlxm, amountToken) = _addLiquidity(token, amountBlxmDesired, amountTokenDesired, amountBlxmMin, amountTokenMin);
        address treasury = getTreasury(token);
        TransferHelper.safeTransferFrom(BLXM, msg.sender, treasury, amountBlxm);
        TransferHelper.safeTransferFrom(token, msg.sender, treasury, amountToken);
        liquidity = _mint(to, token, amountBlxm, amountToken, lockedDays);
    }

    function addLiquidityETH(
        uint amountBlxmDesired,
        uint amountBlxmMin,
        uint amountETHMin,
        address to,
        uint deadline,
        uint16 lockedDays
    ) external override payable ensure(deadline) returns (uint amountBlxm, uint amountETH, uint liquidity) {
        (amountBlxm, amountETH) = _addLiquidity(WETH, amountBlxmDesired, msg.value, amountBlxmMin, amountETHMin);
        address treasury = getTreasury(WETH);
        TransferHelper.safeTransferFrom(BLXM, msg.sender, treasury, amountBlxm);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(treasury, amountETH));
        liquidity = _mint(to, WETH, amountBlxm, amountETH, lockedDays);
        if (msg.value > amountETH) TransferHelper.safeTransferCurrency(msg.sender, msg.value - amountETH); // refund dust, if any
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        uint liquidity,
        uint amountBlxmMin,
        uint amountTokenMin,
        address to,
        uint deadline,
        uint idx
    ) public override ensure(deadline) returns (uint amountBlxm, uint amountToken, uint rewards) {
        (amountBlxm, amountToken, rewards) = _burn(to, liquidity, idx);
        require(amountBlxm >= amountBlxmMin, 'INSUFFICIENT_BLXM_AMOUNT');
        require(amountToken >= amountTokenMin, 'INSUFFICIENT_TOKEN_AMOUNT');
    }
    
    function removeLiquidityETH(
        uint liquidity,
        uint amountBlxmMin,
        uint amountETHMin,
        address to,
        uint deadline,
        uint idx
    ) public override ensure(deadline) returns (uint amountBlxm, uint amountETH, uint rewards) {
        (amountBlxm, amountETH, rewards) = removeLiquidity(liquidity, amountBlxmMin, amountETHMin, address(this), deadline, idx);
        TransferHelper.safeTransfer(BLXM, to, amountBlxm);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferCurrency(to, amountETH);
    }

    function quote(uint amountA, uint reserveA, uint reserveB) public pure override returns (uint amountB) {
        return BLXMLibrary.quote(amountA, reserveA, reserveB);
    }
}