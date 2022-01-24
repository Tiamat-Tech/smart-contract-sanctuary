// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../seed/ISeeder.sol";
import "../withdrawable/Withdrawable.sol";
import "./IDexProxy.sol";

contract DexProxy is IDexProxy, Withdrawable, ReentrancyGuard {
    using SafeMath for *;
    using SafeERC20 for IERC20;

    address public seeder;
    uint256 public immutable divisor = 10000;
    address private constant NATIVE_TOKEN =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // native coin address with checksum

    event Swap(
        address indexed swapper,
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        uint256 buyAmount,
        uint256 climateFee
    );

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
    ) external nonReentrant {
        uint256 initialBalance = IERC20(sellToken).balanceOf(address(this));

        sellToken.safeTransferFrom(msg.sender, address(this), sellAmountMax);
        sellToken.safeIncreaseAllowance(allowanceTarget, sellAmountMax);

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        buyToken.safeTransfer(msg.sender, buyAmount);

        uint256 updatedBalance = IERC20(sellToken).balanceOf(address(this));

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(sellToken));

        uint256 slippage = updatedBalance.sub(initialBalance);
        uint256 climateFee = tokenIssuable ? slippage : 0;

        if (getSeedAmount(address(sellToken), climateFee) > 0) {
            issueSeedsForErc20(sellToken, climateFee);
        } else {
            sellToken.safeTransfer(msg.sender, slippage);
        }

        emit Swap(
            msg.sender,
            address(sellToken),
            address(buyToken),
            sellAmountMax.sub(slippage),
            buyAmount,
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
    ) external nonReentrant {
        uint256 initialBalance = IERC20(sellToken).balanceOf(address(this));

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(sellToken));
        uint256 climateFee = tokenIssuable ? feeAmount : 0;

        if (getSeedAmount(address(sellToken), climateFee) > 0) {
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

        {
            (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
            require(success, "call not successful");
        }

        buyToken.safeTransfer(msg.sender, buyAmount);

        uint256 updatedBalance = IERC20(sellToken).balanceOf(address(this));
        uint256 slippage = updatedBalance.sub(initialBalance);

        if (slippage > 0) {
            sellToken.safeTransfer(msg.sender, slippage);
        }

        emit Swap(
            msg.sender,
            address(sellToken),
            address(buyToken),
            sellAmountMax.sub(slippage),
            buyAmount,
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
    ) external nonReentrant {
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
        uint256 climateFee = tokenIssuable
            ? buyAmount.mul(feePercentage).div(divisor)
            : 0;

        if (getSeedAmount(address(buyToken), climateFee) > 0) {
            uint256 greenBuyAmount = buyAmount.sub(climateFee);
            issueSeedsForErc20(buyToken, climateFee);

            buyToken.safeTransfer(msg.sender, greenBuyAmount);
        } else {
            buyToken.safeTransfer(msg.sender, buyAmount);
        }

        emit Swap(
            msg.sender,
            address(sellToken),
            address(buyToken),
            sellAmountMax.sub(slippage),
            buyAmount.sub(climateFee),
            climateFee
        );
    }

    /**
     * @notice Swaps exact amount of sell token for buy token, send the slippage to a treasury, and
     * issue seeds based on the slippage amount.
     *
     * @param data The call data required to be sent to the to callTarget address.
     * @param callTarget The address of the contract to send call data to.
     * @param allowanceTarget The target contract address for which the user needs to have an allowance.
     * @param sellToken The ERC20 token address of the token that is sent.
     * @param buyToken The ERC20 token address of the token that is received.
     * @param buyAmountMin The minimum amount of buyToken you agree to receive.
     * @param sellAmount The exact amount of sellToken you want to sell.
     *
     * @dev User should set the allowance for the allowanceTarget address to sellAmount in order to
     * be able to complete the swap.
     * after the swap is completed, if the buy token is issuable, the slippage is calculated.
     * if the slippage is greater than 0, the corresponding seeds amount is calculated.
     * if the seeds amount is greater than 0, the seeds are issued to the user and
     * the slippage is sent to the treasury. otherwise, the slippage is sent back to the user.
     */
    function exactSell(
        bytes calldata data,
        address callTarget,
        address allowanceTarget,
        IERC20 sellToken,
        IERC20 buyToken,
        uint256 buyAmountMin,
        uint256 sellAmount
    ) external nonReentrant {
        uint256 initialBalance = IERC20(buyToken).balanceOf(address(this));

        sellToken.safeTransferFrom(msg.sender, address(this), sellAmount);
        sellToken.safeIncreaseAllowance(allowanceTarget, sellAmount);

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        uint256 updatedBalance = IERC20(buyToken).balanceOf(address(this));
        uint256 buyAmount = updatedBalance.sub(initialBalance);

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(buyToken));
        uint256 climateFee = tokenIssuable ? buyAmount.sub(buyAmountMin) : 0;

        if (getSeedAmount(address(buyToken), climateFee) > 0) {
            buyToken.safeTransfer(msg.sender, buyAmountMin);
            issueSeedsForErc20(buyToken, climateFee);
        } else {
            buyToken.safeTransfer(msg.sender, buyAmount);
        }

        emit Swap(
            msg.sender,
            address(sellToken),
            address(buyToken),
            sellAmount,
            buyAmount.sub(climateFee),
            climateFee
        );
    }

    /**
     * @notice Swaps exact amount of native token for buy token, send the slippage to a treasury,
     * and issue seeds based on the slippage amount.
     *
     * @param data The call data required to be sent to the to callTarget address.
     * @param callTarget The address of the contract to send call data to.
     * @param buyToken The ERC20 token address of the token that is received.
     * @param buyAmountMin the minimum amount of buyToken you agree to receive.
     *
     * @dev User should send the sell amount of native token along with the transaction.
     * after the swap is completed, if the buy token is issuable, the slippage is calculated.
     * if the slippage is greater than 0, the corresponding seeds amount is calculated.
     * if the seeds amount is greater than 0, the seeds are issued to the user and
     * the slippage is sent to the treasury. otherwise, the slippage is sent back to the user.
     */
    function exactSellWithSellNative(
        bytes calldata data,
        address callTarget,
        IERC20 buyToken,
        uint256 buyAmountMin
    ) external payable nonReentrant {
        uint256 initialBalance = IERC20(buyToken).balanceOf(address(this));

        (bool success, ) = callTarget.call{value: msg.value}(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        uint256 updatedBalance = IERC20(buyToken).balanceOf(address(this));
        uint256 buyAmount = updatedBalance.sub(initialBalance);

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(buyToken));
        uint256 climateFee = tokenIssuable ? buyAmount.sub(buyAmountMin) : 0;

        if (getSeedAmount(address(buyToken), climateFee) > 0) {
            buyToken.safeTransfer(msg.sender, buyAmountMin);
            issueSeedsForErc20(buyToken, climateFee);
        } else {
            buyToken.safeTransfer(msg.sender, buyAmount);
        }

        emit Swap(
            msg.sender,
            NATIVE_TOKEN,
            address(buyToken),
            msg.value,
            buyAmount.sub(climateFee),
            climateFee
        );
    }

    /**
     * @notice Swaps exact amount of sell token for native token, send the slippage to a treasury, and
     * issue seeds based on the slippage amount.
     *
     * @param data The call data required to be sent to the to callTarget address.
     * @param callTarget The address of the contract to send call data to.
     * @param allowanceTarget The target contract address for which the user needs to have an allowance.
     * @param sellToken The ERC20 token address of the token that is sent.
     * @param buyAmountMin the minimum amount of native token you agree to receive.
     * @param sellAmount the exact amount of sellToken you want to sell.
     *
     * @dev User should set the allowance for the allowanceTarget address to sellAmount in order to
     * be able to complete the swap.
     * after the swap is completed, if the native token is issuable, the slippage is calculated.
     * if the slippage is greater than 0, the corresponding seeds amount is calculated.
     * if the seeds amount is greater than 0, the seeds are issued to the user and
     * the slippage is sent to the treasury.
     * otherwise, the slippage is sent back to the user.
     * if the caller is a contract, it should contain a payable fallback function.
     */
    function exactSellWithBuyNative(
        bytes calldata data,
        address callTarget,
        address allowanceTarget,
        IERC20 sellToken,
        uint256 buyAmountMin,
        uint256 sellAmount
    ) external nonReentrant {
        // uint256 initialBalance = IERC20(buyToken).balanceOf(address(this));
        uint256 initialBalance = address(this).balance;

        sellToken.safeTransferFrom(msg.sender, address(this), sellAmount);
        sellToken.safeIncreaseAllowance(allowanceTarget, sellAmount);

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        // uint256 updatedBalance = IERC20(buyToken).balanceOf(address(this));
        uint256 updatedBalance = address(this).balance;
        uint256 buyAmount = updatedBalance.sub(initialBalance);

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(NATIVE_TOKEN);
        uint256 climateFee = tokenIssuable ? buyAmount.sub(buyAmountMin) : 0;

        if (getSeedAmount(address(NATIVE_TOKEN), climateFee) > 0) {
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

        emit Swap(
            msg.sender,
            address(sellToken),
            NATIVE_TOKEN,
            sellAmount,
            buyAmount.sub(climateFee),
            climateFee
        );
    }

    /**
     * @notice Swaps exact amount of sell token for buy token, send the feeAmount to a treasury, and
     * issue seeds based on the feeAmount amount.
     *
     * @param data The call data required to be sent to the to callTarget address.
     * @param callTarget The address of the contract to send call data to.
     * @param allowanceTarget The target contract address for which the user needs to have an allowance.
     * @param sellToken The ERC20 token address of the token that is sent.
     * @param buyToken The ERC20 token address of the token that is received.
     * @param sellAmount The exact amount of sellToken you want to sell.
     * @param feeAmount Exact amount of sell token paid by the caller as a fee.
     *
     * @dev User should set the allowance for the allowanceTarget address to sellAmount in order to
     * be able to complete the swap.
     * after the swap is completed, if the sell token is issuable, the corresponding seeds amount is
     * calculated base on feeAmount.
     * if the seeds amount is greater than 0, the seeds are issued to the user and the feeAmount is
     * sent to the treasury.
     * otherwise, the feeAmount is sent back to the user.
     */
    function exactSellWithSellFee(
        bytes calldata data,
        address callTarget,
        address allowanceTarget,
        IERC20 sellToken,
        IERC20 buyToken,
        uint256 sellAmount,
        uint256 feeAmount
    ) external nonReentrant {
        uint256 initialBalance = IERC20(buyToken).balanceOf(address(this));

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(sellToken));

        uint256 climateFee = tokenIssuable ? feeAmount : 0;

        if (getSeedAmount(address(sellToken), climateFee) > 0) {
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

        emit Swap(
            msg.sender,
            address(sellToken),
            address(buyToken),
            sellAmount.sub(climateFee),
            buyAmount,
            climateFee
        );
    }

    /**
     * @notice Swaps exact amount of sell token for buy token, send the feePercentage to a treasury, and
     * issue seeds based on the feePercentage.
     *
     * @param data The call data required to be sent to the to callTarget address.
     * @param callTarget The address of the contract to send call data to.
     * @param allowanceTarget The target contract address for which the user needs to have an allowance.
     * @param sellToken The ERC20 token address of the token that is sent.
     * @param buyToken The ERC20 token address of the token that is received.
     * @param sellAmount The exact amount of sellToken you want to sell.
     * @param feePercentage The percentage of buy token paid by the caller as a climate fee.(up to 2 decimals)
     *
     * @dev User should set the allowance for the allowanceTarget address to sellAmount in order to
     * be able to complete the swap.
     * after the swap is completed, if the buy token is issuable, the corresponding seeds amount is
     * calculated base on feePercentage.
     * if the seeds amount is greater than 0, the seeds are issued to the user and
     * the feePercentage is sent to the treasury.
     * otherwise, the feePercentage is sent back to the user.
     */
    function exactSellWithBuyFee(
        bytes calldata data,
        address callTarget,
        address allowanceTarget,
        IERC20 sellToken,
        IERC20 buyToken,
        uint256 sellAmount,
        uint256 feePercentage
    ) external nonReentrant {
        uint256 initialBalance = IERC20(buyToken).balanceOf(address(this));

        sellToken.safeTransferFrom(msg.sender, address(this), sellAmount);
        sellToken.safeIncreaseAllowance(allowanceTarget, sellAmount);

        (bool success, ) = callTarget.call(data); // solhint-disable-line avoid-low-level-calls
        require(success, "call not successful");

        uint256 updatedBalance = IERC20(buyToken).balanceOf(address(this));
        uint256 buyAmount = updatedBalance.sub(initialBalance);

        bool tokenIssuable = ISeeder(seeder).tokenIssuable(address(buyToken));
        uint256 climateFee = tokenIssuable
            ? buyAmount.mul(feePercentage).div(divisor)
            : 0;

        if (getSeedAmount(address(buyToken), climateFee) > 0) {
            uint256 greenBuyAmount = buyAmount.sub(climateFee);

            buyToken.safeTransfer(msg.sender, greenBuyAmount);

            issueSeedsForErc20(buyToken, climateFee);
        } else {
            buyToken.safeTransfer(msg.sender, buyAmount);
        }

        emit Swap(
            msg.sender,
            address(sellToken),
            address(buyToken),
            sellAmount,
            buyAmount.sub(climateFee),
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
            ISeeder(seeder).issueSeedsForNative{value: climateFee}(msg.sender);
        }
    }

    function getSeedAmount(address feeToken, uint256 feeAmount)
        public
        view
        returns (uint256)
    {
        return
            feeAmount > 0
                ? ISeeder(seeder).getSeedAmount(feeToken, feeAmount)
                : 0;
    }
}