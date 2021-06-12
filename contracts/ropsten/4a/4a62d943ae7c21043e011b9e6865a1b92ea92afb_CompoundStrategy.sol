//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;
import "../interfaces/IRhoStrategy.sol";
import "../interfaces/ICERC20.sol";
import "../interfaces/IComptroller.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {
    IERC20Upgradeable as IERC20
} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/IUniswapV2Router02.sol";

contract CompoundStrategy is
    IRhoStrategy,
    PausableUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20 public underlying;
    ICERC20 public cToken;
    IComptroller public comptroller;
    uint256 private _rewardConversionThreshold;

    IERC20 private comp;
    IUniswapV2Router02 private uniswap;
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");

    function initialize(
        address _underlyingAddr,
        address _ctokenAddr,
        address _comptrollerAddr,
        address _uniswapV2Router02Addr,
        address _compAddr
    ) public initializer {
        PausableUpgradeable.__Pausable_init();
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        underlying = IERC20Upgradeable(_underlyingAddr);
        cToken = ICERC20(_ctokenAddr);
        comptroller = IComptroller(_comptrollerAddr);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        uniswap = IUniswapV2Router02(_uniswapV2Router02Addr);
        comp = IERC20(_compAddr);
    }

    function getSupplyRate() external pure override returns (uint256 _amount) {
        return 1;
    }

    function getDeployableAmount()
        external
        pure
        override
        returns (uint256 _amount)
    {
        return 1;
    }

    function deploy(uint256 _amount) public override onlyRole(VAULT_ROLE) {
        require(_amount > 0, "CompoundStrategy: deploy amount zero");
        underlying.safeIncreaseAllowance(address(cToken), _amount);
        assert(cToken.mint(_amount) == 0);
    }

    function withdrawUnderlying(uint256 _amount)
        public
        override
        onlyRole(VAULT_ROLE)
    {
        require(
            cToken.redeemUnderlying(_amount) == 0,
            "CompoundStrategy: Fail to withdraw from compound"
        );
        underlying.safeTransfer(_msgSender(), _amount);
    }

    function withdrawAll() external override onlyRole(VAULT_ROLE) {
        require(
            cToken.redeem(cToken.balanceOf(address(this))) == 0,
            "CompoundStrategy: Fail to withdraw from compound"
        );
    }

    function collectRewardToken() external override onlyRole(VAULT_ROLE) {
        comptroller.claimComp(address(this));
    }

    function setRewardConversionThreshold(uint256 _threshold)
        external
        override
        onlyRole(VAULT_ROLE)
        returns (uint256)
    {
        _rewardConversionThreshold = _threshold;
        return _rewardConversionThreshold;
    }

    function rewardConversionThreshold()
        external
        view
        override
        returns (uint256)
    {
        return _rewardConversionThreshold;
    }

    function balanceOfUnderlying() external override returns (uint256) {
        return cToken.balanceOfUnderlying(address(this));
    }

    function swapToken(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        uint256 deadline
    ) external onlyRole(VAULT_ROLE) {
        require(
            comp.balanceOf(address(this)) >= amountIn,
            "not enough balance"
        );
        require(amountIn > 0, "amountIn cannot be 0");
        require(
            path[0] == address(comp)&&path[path.length - 1] == address(underlying),
            "path index 0 and index last should match stragegy award token and underlying token"
        );
        comp.safeIncreaseAllowance(address(uniswap), amountIn);

        uint256[] memory amounts =
            uniswap.swapExactTokensForTokens(
                amountIn,
                amountOutMin,
                path,
                address(this),
                deadline
            );
    }
    // withdraw random token transfer into this contract
    function sweepERC20Token(address token, address to)external override onlyRole(SWEEPER_ROLE){
        require(token != address(underlying), "!safe");
        require(token != address(cToken), "!safe");
        IERC20Upgradeable tokenToSweep = IERC20Upgradeable(token);
        tokenToSweep.transfer(to, tokenToSweep.balanceOf(address(this)));
    }


}