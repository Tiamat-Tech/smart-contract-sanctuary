// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../seed/ISeeder.sol";
import "./IProxy0x.sol";

contract Proxy0x is IProxy0x, Ownable {
    using SafeMath for *;
    using SafeERC20 for IERC20;

    address public seeder;
    uint256 public immutable divisor = 10000;
    address public immutable nativeAddress =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // native coin address with checksum

    constructor(address _seeder) {
        seeder = _seeder;
    }

    function setSeeder(address _seeder) external onlyOwner {
        seeder = _seeder;
    }

    function exactBuy(
        bytes calldata data,
        address callTarget,
        address allowanceTarget,
        IERC20 sellToken,
        IERC20 buyToken,
        uint256 sellAmountMax,
        uint256 buyAmount
    ) external {
        uint256 initialBalance = IERC20(sellToken).balanceOf(address(this));

        sellToken.safeTransferFrom(msg.sender, address(this), sellAmountMax);
        sellToken.safeIncreaseAllowance(allowanceTarget, sellAmountMax);

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        buyToken.safeTransfer(msg.sender, buyAmount);

        uint256 updatedBalance = IERC20(sellToken).balanceOf(address(this));

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(buyToken));

        uint256 climateFee = 0;

        if (tokenIssuable) {
            climateFee = updatedBalance.sub(initialBalance);
            issueSeedsForErc20(sellToken, climateFee);
        } else {
            sellToken.safeTransfer(msg.sender, climateFee);
        }

        emit Swapped(
            msg.sender,
            address(sellToken),
            address(buyToken),
            climateFee
        );
    }

    function exactBuyWithSellFee(
        bytes calldata data,
        address callTarget,
        address allowanceTarget,
        IERC20 sellToken,
        IERC20 buyToken,
        uint256 sellAmountMax,
        uint256 buyAmount,
        uint256 feeAmount
    ) external {
        uint256 initialBalance = IERC20(sellToken).balanceOf(address(this));

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(sellToken));

        uint256 climateFee = 0;

        if (tokenIssuable) {
            climateFee = feeAmount;

            uint256 greenSellAmount = sellAmountMax.add(feeAmount);

            sellToken.safeTransferFrom(
                msg.sender,
                address(this),
                greenSellAmount
            );
            sellToken.safeIncreaseAllowance(allowanceTarget, sellAmountMax);

            issueSeedsForErc20(sellToken, climateFee);
        } else {
            sellToken.safeTransferFrom(
                msg.sender,
                address(this),
                sellAmountMax
            );
            sellToken.safeIncreaseAllowance(allowanceTarget, sellAmountMax);
        }

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        buyToken.safeTransfer(msg.sender, buyAmount);

        uint256 updatedBalance = IERC20(sellToken).balanceOf(address(this));
        uint256 slippage = updatedBalance.sub(initialBalance);

        if (slippage > 0) {
            sellToken.safeTransfer(msg.sender, slippage);
        }

        emit Swapped(
            msg.sender,
            address(sellToken),
            address(buyToken),
            climateFee
        );
    }

    function exactBuyWithBuyFee(
        bytes calldata data,
        address callTarget,
        address allowanceTarget,
        IERC20 sellToken,
        IERC20 buyToken,
        uint256 sellAmountMax,
        uint256 buyAmount,
        uint256 feePercentage
    ) external {
        uint256 initialBalance = IERC20(sellToken).balanceOf(address(this));

        sellToken.safeTransferFrom(msg.sender, address(this), sellAmountMax);
        sellToken.safeIncreaseAllowance(allowanceTarget, sellAmountMax);

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        uint256 updatedBalance = IERC20(sellToken).balanceOf(address(this));
        uint256 slippage = updatedBalance.sub(initialBalance);

        if (slippage > 0) {
            sellToken.safeTransfer(msg.sender, slippage);
        }

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(buyToken));

        uint256 climateFee = 0;

        if (tokenIssuable) {
            climateFee = buyAmount.mul(feePercentage).div(divisor);
            uint256 greenBuyAmount = buyAmount.sub(climateFee);
            issueSeedsForErc20(buyToken, climateFee);

            buyToken.safeTransfer(msg.sender, greenBuyAmount);
        } else {
            sellToken.safeTransfer(msg.sender, buyAmount);
        }

        emit Swapped(
            msg.sender,
            address(sellToken),
            address(buyToken),
            climateFee
        );
    }

    function exactSell(
        bytes calldata data,
        address callTarget,
        address allowanceTarget,
        IERC20 sellToken,
        IERC20 buyToken,
        uint256 buyAmountMin,
        uint256 sellAmount
    ) external {
        uint256 initialBalance = IERC20(buyToken).balanceOf(address(this));

        sellToken.safeTransferFrom(msg.sender, address(this), sellAmount);
        sellToken.safeIncreaseAllowance(allowanceTarget, sellAmount);

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        uint256 updatedBalance = IERC20(buyToken).balanceOf(address(this));
        uint256 buyAmount = updatedBalance.sub(initialBalance);

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(buyToken));

        uint256 climateFee = 0;

        if (tokenIssuable) {
            climateFee = buyAmount.sub(buyAmountMin);
            buyToken.safeTransfer(msg.sender, buyAmountMin);
            // issueSeedsForErc20(buyToken, climateFee);
        } else {
            buyToken.safeTransfer(msg.sender, buyAmount);
        }

        emit Swapped(
            msg.sender,
            address(sellToken),
            address(buyToken),
            climateFee
        );
    }

    function exactSellWithSellNative(
        bytes calldata data,
        address callTarget,
        IERC20 buyToken,
        uint256 buyAmountMin
    ) external payable {
        uint256 initialBalance = IERC20(buyToken).balanceOf(address(this));

        (bool success, ) = callTarget.call{value: msg.value}(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        uint256 updatedBalance = IERC20(buyToken).balanceOf(address(this));
        uint256 buyAmount = updatedBalance.sub(initialBalance);

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(buyToken));

        uint256 climateFee = 0;

        if (tokenIssuable) {
            climateFee = buyAmount.sub(buyAmountMin);
            buyToken.safeTransfer(msg.sender, buyAmountMin);

            issueSeedsForErc20(buyToken, climateFee);
        } else {
            buyToken.safeTransfer(msg.sender, buyAmount);
        }

        emit Swapped(msg.sender, nativeAddress, address(buyToken), climateFee);
    }

    function exactSellWithBuyNative(
        bytes calldata data,
        address callTarget,
        address allowanceTarget,
        IERC20 sellToken,
        uint256 buyAmountMin,
        uint256 sellAmount
    ) external {
        // uint256 initialBalance = IERC20(buyToken).balanceOf(address(this));
        uint256 initialBalance = address(this).balance;

        sellToken.safeTransferFrom(msg.sender, address(this), sellAmount);
        sellToken.safeIncreaseAllowance(allowanceTarget, sellAmount);

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        // uint256 updatedBalance = IERC20(buyToken).balanceOf(address(this));
        uint256 updatedBalance = address(this).balance;
        uint256 buyAmount = updatedBalance.sub(initialBalance);

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(nativeAddress);

        uint256 climateFee = 0;

        if (tokenIssuable) {
            climateFee = buyAmount.sub(buyAmountMin);

            (bool successTransfer, ) = msg.sender.call{value: buyAmountMin}( // solhint-disable-line avoid-low-level-calls
                new bytes(0)
            );
            require(successTransfer, "Native Token transfer failed");

            issueSeedsForNative(climateFee);
        } else {
            (bool successTransfer, ) = msg.sender.call{value: buyAmount}( // solhint-disable-line avoid-low-level-calls
                new bytes(0)
            );
            require(successTransfer, "Native Token transfer failed");
        }

        emit Swapped(msg.sender, address(sellToken), nativeAddress, climateFee);
    }

    function exactSellWithSellFee(
        bytes calldata data,
        address callTarget,
        address allowanceTarget,
        IERC20 sellToken,
        IERC20 buyToken,
        uint256 sellAmount,
        uint256 feeAmount
    ) external {
        uint256 initialBalance = IERC20(buyToken).balanceOf(address(this));

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(sellToken));

        uint256 climateFee = 0;

        if (tokenIssuable) {
            climateFee = feeAmount;

            uint256 greenSellAmount = sellAmount.add(feeAmount);

            sellToken.safeTransferFrom(
                msg.sender,
                address(this),
                greenSellAmount
            );
            sellToken.safeIncreaseAllowance(allowanceTarget, sellAmount);

            issueSeedsForErc20(sellToken, climateFee);
        } else {
            sellToken.safeTransferFrom(msg.sender, address(this), sellAmount);
            sellToken.safeIncreaseAllowance(allowanceTarget, sellAmount);
        }

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        uint256 updatedBalance = IERC20(buyToken).balanceOf(address(this));
        uint256 buyAmount = updatedBalance.sub(initialBalance);

        buyToken.safeTransfer(msg.sender, buyAmount);

        emit Swapped(
            msg.sender,
            address(sellToken),
            address(buyToken),
            climateFee
        );
    }

    function exactSellWithBuyFee(
        bytes calldata data,
        address callTarget,
        address allowanceTarget,
        IERC20 sellToken,
        IERC20 buyToken,
        uint256 sellAmount,
        uint256 feePercentage
    ) external {
        uint256 initialBalance = IERC20(buyToken).balanceOf(address(this));

        sellToken.safeTransferFrom(msg.sender, address(this), sellAmount);
        sellToken.safeIncreaseAllowance(allowanceTarget, sellAmount);

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        uint256 updatedBalance = IERC20(buyToken).balanceOf(address(this));
        uint256 buyAmount = updatedBalance.sub(initialBalance);

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(buyToken));

        uint256 climateFee = 0;

        if (tokenIssuable) {
            climateFee = buyAmount.mul(feePercentage).div(divisor);
            uint256 greenBuyAmount = buyAmount.sub(climateFee);

            buyToken.safeTransfer(msg.sender, greenBuyAmount);

            issueSeedsForErc20(buyToken, climateFee);
        } else {
            buyToken.safeTransfer(msg.sender, buyAmount);
        }

        emit Swapped(
            msg.sender,
            address(sellToken),
            address(buyToken),
            climateFee
        );
    }

    function issueSeedsForErc20(IERC20 token, uint256 climateFee) private {
        if (climateFee > 0) {
            token.safeIncreaseAllowance(seeder, climateFee);

            ISeeder(seeder).issueSeedsForErc20(
                msg.sender,
                address(token),
                climateFee
            );
        }
    }

    function issueSeedsForNative(uint256 climateFee) private {
        if (climateFee > 0) {
            ISeeder(seeder).issueSeedsForNative{value: climateFee}(
                msg.sender,
                nativeAddress,
                climateFee
            );
        }
    }

    function getSeedPerFee(address feeToken) external view returns (uint256) {
        return ISeeder(seeder).seedPerFee(feeToken);
    }

    receive() external payable virtual {} // solhint-disable-line no-empty-blocks
}