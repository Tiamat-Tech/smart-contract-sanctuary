// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../seed/ISeeder.sol";

contract Proxy0x is Ownable {
    using SafeMath for *;
    using SafeERC20 for IERC20;

    address public seeder;

    event Swapped(
        address sender,
        address inputToken,
        address outputToken,
        uint256 indexed excessSlippage
    );

    constructor(address _seeder) {
        seeder = _seeder;
    }

    function setSeeder(address _seeder) external onlyOwner {
        seeder = _seeder;
    }

    function exactOutput(
        bytes memory data,
        address callTarget,
        address allowanceTarget,
        IERC20 inputToken,
        IERC20 outputToken,
        uint256 amountInMax,
        uint256 amountOut
    ) external {
        uint256 initialBalance = IERC20(inputToken).balanceOf(address(this));

        inputToken.safeTransferFrom(msg.sender, address(this), amountInMax);
        inputToken.safeApprove(allowanceTarget, amountInMax);

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        outputToken.safeTransfer(msg.sender, amountOut);

        uint256 updatedBalance = IERC20(inputToken).balanceOf(address(this));
        uint256 excessSlippage = updatedBalance.sub(initialBalance);

        if (excessSlippage > 0) {
            inputToken.safeApprove(seeder, excessSlippage);

            ISeeder(seeder).issueSeeds(
                msg.sender,
                address(inputToken),
                excessSlippage
            );
        }

        emit Swapped(
            msg.sender,
            address(inputToken),
            address(outputToken),
            excessSlippage
        );
    }

    function exactInput(
        bytes memory data,
        address callTarget,
        address allowanceTarget,
        IERC20 inputToken,
        IERC20 outputToken,
        uint256 amountOutMin,
        uint256 amountIn
    ) external {
        uint256 initialBalance = IERC20(outputToken).balanceOf(address(this));

        inputToken.safeTransferFrom(msg.sender, address(this), amountIn);
        inputToken.safeApprove(allowanceTarget, amountIn);

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        outputToken.safeTransfer(msg.sender, amountOutMin);

        uint256 updatedBalance = IERC20(outputToken).balanceOf(address(this));
        uint256 excessSlippage = updatedBalance.sub(initialBalance);

        if (excessSlippage > 0) {
            outputToken.safeApprove(seeder, excessSlippage);

            ISeeder(seeder).issueSeeds(
                msg.sender,
                address(outputToken),
                excessSlippage
            );
        }

        emit Swapped(
            msg.sender,
            address(inputToken),
            address(outputToken),
            excessSlippage
        );
    }
}