pragma solidity ^0.8.0;

import "../interfaces/ISwapRouter.sol";
import "./RevenueShare.sol";
import "../libraries/Constants.sol";

contract RevenueShareVault is RevenueShare, Constants {

    ISwapRouter public swapRouter;
    IERC20 public revenueToken;

    constructor(
        IERC20 _underlying,
        IERC20 _revenueToken,
        string memory _name,
        string memory _symbol,
        ISwapRouter _swapRouter
    ) RevenueShare(IERC20(_underlying), _name, _symbol) {
        swapRouter = _swapRouter;
        revenueToken = _revenueToken;
    }

    function compound() external {
        uint balance = revenueToken.balanceOf(address(this));

        if (revenueToken.allowance(address(this), address(swapRouter)) < MAX_INT) {
            revenueToken.approve(address(swapRouter), MAX_INT);
        }

        swapRouter.compound(address(revenueToken), balance);
    }

}