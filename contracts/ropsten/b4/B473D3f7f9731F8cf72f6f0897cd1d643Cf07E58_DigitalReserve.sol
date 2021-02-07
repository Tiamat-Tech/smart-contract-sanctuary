// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.6.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/Uniswap/IUniswapV2Router02.sol";
import "./interfaces/IDigitalReserve.sol";

/**
 * @dev Implementation of Digital Reserve contract.
 * Digital Reserve contract converts user's DRC into a set of SoV assets using the Uniswap router,
 * and hold these assets for it's users.
 * When users initiate a withdrawal action, the contract converts a share of the vault,
 * that the user is requesting, to DRC and sends it back to their wallet.
 */
contract DigitalReserve is IDigitalReserve, ERC20, Ownable {
    using SafeMath for uint256;

    /**
     * @dev Set Uniswap router address, DRC token address, DR name.
     */
    constructor(
        address _router,
        address _drcAddress,
        string memory _name
    ) public ERC20(_name, "DR-POD") {
        drcAddress = _drcAddress;
        router = _router;
        uniswapRouter = IUniswapV2Router02(_router);
    }

    uint8 private _strategyTokenCount;
    address[] private _strategyTokens;
    mapping(address => uint8) private _tokenPercentage;
    uint8 private _withdrawalFeeFraction = 1;
    uint8 private _withdrawalFeeBase = 100;
    uint8 private _priceDecimals = 18;

    address private router;
    address private drcAddress;

    bool private depositEnabled = false;

    IUniswapV2Router02 private uniswapRouter;

    /**
     * @dev See {IDigitalReserve-strategyTokenCount}.
     */
    function strategyTokenCount() external view override returns (uint8) {
        return _strategyTokenCount;
    }

    /**
     * @dev See {IDigitalReserve-strategyTokens}.
     */
    function strategyTokens(uint8 index) external view override returns (address) {
        return _strategyTokens[index];
    }

    /**
     * @dev See {IDigitalReserve-tokenPercentage}.
     */
    function tokenPercentage(address tokenAddress) external view override returns (uint8) {
        return _tokenPercentage[tokenAddress];
    }

    /**
     * @dev See {IDigitalReserve-withdrawalFee}.
     */
    function withdrawalFee() external view override returns (uint8, uint8) {
        return (_withdrawalFeeFraction, _withdrawalFeeBase);
    }

    /**
     * @dev See {IDigitalReserve-priceDecimals}.
     */
    function priceDecimals() external view override returns (uint8) {
        return _priceDecimals;
    }

    /**
     * @dev See {IDigitalReserve-totalTokenStored}.
     */
    function totalTokenStored() public view override returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](_strategyTokenCount);
        for (uint8 i = 0; i < _strategyTokenCount; i++) {
            amounts[i] = IERC20(_strategyTokens[i]).balanceOf(address(this));
        }
        return amounts;
    }

    /**
     * @dev See {IDigitalReserve-getUserVaultInDrc}.
     */
    function getUserVaultInDrc(
        address user, 
        uint8 percentage
    ) public view override returns (uint256, uint256, uint256) {
        uint256[] memory userStrategyTokens = _getStrategyTokensByPodAmount(balanceOf(user).mul(percentage).div(100));
        uint256 userVaultWorthInEth = _getEthAmountByStrategyTokensAmount(userStrategyTokens, true);
        uint256 userVaultWorthInEthAfterSwap = _getEthAmountByStrategyTokensAmount(userStrategyTokens, false);

        uint256 drcAmountBeforeFees = _getTokenAmountByEthAmount(userVaultWorthInEth, drcAddress, true);

        uint256 fees = userVaultWorthInEthAfterSwap.mul(_withdrawalFeeFraction).div(_withdrawalFeeBase);
        uint256 drcAmountAfterFees = _getTokenAmountByEthAmount(userVaultWorthInEthAfterSwap.sub(fees), drcAddress, false);

        return (drcAmountBeforeFees, drcAmountAfterFees, fees);
    }

    /**
     * @dev See {IDigitalReserve-getProofOfDepositPrice}.
     */
    function getProofOfDepositPrice() public view override returns (uint256) {
        uint256 proofOfDepositPrice;
        if (totalSupply() > 0) {
            proofOfDepositPrice = _getEthAmountByStrategyTokensAmount(totalTokenStored(), true).mul(1e18).div(totalSupply());
        }
        return proofOfDepositPrice;
    }

    /**
     * @dev See {IDigitalReserve-depositDrc}.
     */
    function depositDrc(uint256 drcAmount, uint32 deadline) external override {
        require(_strategyTokenCount >= 1, "Strategy hasn't been set.");
        require(depositEnabled, "Deposit is disabled.");
        require(IERC20(drcAddress).allowance(msg.sender, address(this)) >= drcAmount, "Contract is not allowed to spend user's DRC.");
        require(IERC20(drcAddress).balanceOf(msg.sender) >= drcAmount, "Attempted to deposit more than balance.");

        SafeERC20.safeTransferFrom(IERC20(drcAddress), msg.sender, address(this), drcAmount);

        // Get current unit price before adding tokens to vault
        uint256 currentPodUnitPrice = getProofOfDepositPrice();

        uint256 ethConverted = _convertTokenToEth(drcAmount, drcAddress, deadline);
        _convertEthToStrategyTokens(ethConverted, deadline);

        uint256 podToMint = 0;
        if (totalSupply() == 0) {
            podToMint = drcAmount.mul(1e15);
        } else {
            uint256 vaultTotalInEth = _getEthAmountByStrategyTokensAmount(totalTokenStored(), true);
            uint256 newPodTotal = vaultTotalInEth.mul(1e18).div(currentPodUnitPrice);
            podToMint = newPodTotal.sub(totalSupply());
        }

        _mint(msg.sender, podToMint);

        emit Deposit(msg.sender, drcAmount, podToMint, totalSupply(), totalTokenStored());
    }

    /**
     * @dev See {IDigitalReserve-withdrawDrc}.
     */
    function withdrawDrc(uint256 drcAmount, uint32 deadline) external override {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = drcAddress;

        uint256 ethNeeded = uniswapRouter.getAmountsIn(drcAmount, path)[0];
        uint256 ethNeededPlusFee = ethNeeded.mul(_withdrawalFeeBase).div(_withdrawalFeeBase - _withdrawalFeeFraction);

        uint256[] memory userStrategyTokens = _getStrategyTokensByPodAmount(balanceOf(msg.sender));
        uint256 userVaultWorth = _getEthAmountByStrategyTokensAmount(userStrategyTokens, false);

        require(userVaultWorth >= ethNeededPlusFee, "Attempt to withdraw more than user's holding.");

        uint256 amountFraction = ethNeededPlusFee.mul(1e10).div(userVaultWorth);
        uint256 podToBurn = balanceOf(msg.sender).mul(amountFraction).div(1e10);

        _withdrawProofOfDeposit(podToBurn, deadline);
    }

    /**
     * @dev See {IDigitalReserve-withdrawPercentage}.
     */
    function withdrawPercentage(uint8 percentage, uint32 deadline) external override {
        require(percentage <= 100, "Attempt to withdraw more than 100% of the asset");

        uint256 podToBurn = balanceOf(msg.sender).mul(percentage).div(100);
        _withdrawProofOfDeposit(podToBurn, deadline);
    }

    /**
     * @dev Enable or disable deposit.
     * @param status Deposit allowed or not
     * Disable deposit if it is to protect users' fund if there's any security issue or assist DR upgrade.
     */
    function changeDepositStatus(bool status) external onlyOwner {
        depositEnabled = status;
    }

    /**
     * @dev Change withdrawal fee percentage.
     * If 1%, then input (1,100)
     * If 0.5%, then input (5,1000)
     * @param withdrawalFeeFraction_ Fraction of withdrawal fee based on withdrawalFeeBase_
     * @param withdrawalFeeBase_ Fraction of withdrawal fee base
     */
    function changeFee(uint8 withdrawalFeeFraction_, uint8 withdrawalFeeBase_) external onlyOwner {
        require(withdrawalFeeFraction_ <= withdrawalFeeBase_, "Fee fraction exceeded base.");
        uint8 percentage = (withdrawalFeeFraction_ * 100) / withdrawalFeeBase_;
        require(percentage <= 2, "Attempt to set percentage higher than 2%."); // Requested by community

        _withdrawalFeeFraction = withdrawalFeeFraction_;
        _withdrawalFeeBase = withdrawalFeeBase_;
    }

    /**
     * @dev Set or change DR strategy tokens and allocations.
     * @param strategyTokens_ Array of strategy tokens.
     * @param tokenPercentage_ Array of strategy tokens' percentage allocations.
     * @param strategyTokenCount_ Number of strategy tokens.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function changeStrategy(
        address[] calldata strategyTokens_,
        uint8[] calldata tokenPercentage_,
        uint8 strategyTokenCount_,
        uint32 deadline
    ) external onlyOwner {
        require(strategyTokenCount_ >= 1, "Setting strategy to 0 tokens.");
        require(strategyTokens_.length == strategyTokenCount_, "Token count doesn't match tokens length.");
        require(tokenPercentage_.length == strategyTokenCount_, "Token count doesn't match token percentages length.");

        uint8 totalPercentage = 0;
        for (uint8 i = 0; i < strategyTokenCount_; i++) {
            totalPercentage += tokenPercentage_[i];
        }
        require(totalPercentage == 100, "Total token percentage is not 100%.");

        address[] memory oldTokens = _strategyTokens;
        uint8[] memory oldPercentage = new uint8[](_strategyTokenCount);
        for (uint8 i = 0; i < _strategyTokenCount; i++) {
            oldPercentage[i] = _tokenPercentage[_strategyTokens[i]];
            delete _tokenPercentage[_strategyTokens[i]];
        }

        // Before mutate strategyTokens, convert current strategy tokens to ETH
        uint256 ethConverted = _convertStrategyTokensToEth(totalTokenStored(), deadline);

        _strategyTokens = strategyTokens_;
        _strategyTokenCount = strategyTokenCount_;
        for (uint8 i = 0; i < _strategyTokenCount; i++) {
            _tokenPercentage[_strategyTokens[i]] = tokenPercentage_[i];
        }

        _convertEthToStrategyTokens(ethConverted, deadline);

        emit StrategyChange(oldTokens, oldPercentage, _strategyTokens, tokenPercentage_, totalTokenStored());
    }

    /**
     * @dev Realigning the weighting of a portfolio of assets to the strategy allocation that is defined.
     * Only convert the amount that's necessory to convert to not be charged 0.3% uniswap fee for everything.
     * This in total saves 0.6% fee for majority of the assets.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function rebalance(uint32 deadline) external onlyOwner {
        require(_strategyTokenCount > 0, "Strategy hasn't been set");

        // Get each tokens worth and the total worth in ETH
        uint256 totalWorthInEth;
        uint256[] memory tokensWorthInEth = new uint256[](_strategyTokenCount);

        for (uint8 i = 0; i < _strategyTokenCount; i++) {
            uint256 tokenWorth = _getEthAmountByTokenAmount(IERC20(_strategyTokens[i]).balanceOf(address(this)), _strategyTokens[i], true);
            totalWorthInEth = totalWorthInEth.add(tokenWorth);
            tokensWorthInEth[i] = tokenWorth;
        }

        uint8[] memory percentageArray = new uint8[](_strategyTokenCount); // Get percentages for event param
        uint256 totalInEthToConvert = 0; // Get total token worth in ETH needed to be converted
        uint256 totalEthConverted = 0; // Get total token worth in ETH needed to be converted
        uint256[] memory tokenInEthNeeded = new uint256[](_strategyTokenCount); // Get token worth need to be filled

        for (uint8 i = 0; i < _strategyTokenCount; i++) {
            percentageArray[i] = _tokenPercentage[_strategyTokens[i]];

            uint256 tokenShouldWorth = totalWorthInEth.mul(_tokenPercentage[_strategyTokens[i]]).div(100);

            if (tokensWorthInEth[i] <= tokenShouldWorth) {
                // If token worth less than should be, calculate the diff and store as needed
                tokenInEthNeeded[i] = tokenShouldWorth.sub(tokensWorthInEth[i]);
                totalInEthToConvert = totalInEthToConvert.add(tokenInEthNeeded[i]);
            } else {
                tokenInEthNeeded[i] = 0;

                // If token worth more than should be, convert the overflowed amount to ETH
                uint256 tokenInEthOverflowed = tokensWorthInEth[i].sub(tokenShouldWorth);
                uint256 tokensToConvert = _getTokenAmountByEthAmount(tokenInEthOverflowed, _strategyTokens[i], true);
                uint256 ethConverted = _convertTokenToEth(tokensToConvert, _strategyTokens[i], deadline);
                totalEthConverted = totalEthConverted.add(ethConverted);
            }
            // Need the total value to help calculate how to distributed the converted ETH
        }

        // Distribute newly converted ETH by portion of each token to be converted to, and convert to that token needed.
        // Note: totalEthConverted would be a bit smaller than totalInEthToConvert due to Uniswap fee.
        // Converting everything is another way of rebalancing, but Uniswap would take 0.6% fee on everything.
        // In this method we reach the closest number with the lowest possible swapping fee.
        for (uint8 i = 0; i < _strategyTokenCount; i++) {
            uint256 ethToConvert = totalEthConverted.mul(tokenInEthNeeded[i]).div(totalInEthToConvert);
            _convertEthToToken(ethToConvert, _strategyTokens[i], deadline);
        }

        emit Rebalance(_strategyTokens, percentageArray, totalTokenStored());
    }

    /**
     * @dev Withdraw DRC by DR-POD amount to burn.
     * @param podToBurn Amount of DR-POD to burn in exchange for DRC.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function _withdrawProofOfDeposit(uint256 podToBurn, uint32 deadline) private {
        uint256[] memory strategyTokensToWithdraw = _getStrategyTokensByPodAmount(podToBurn);

        _burn(msg.sender, podToBurn);

        uint256 ethConverted = _convertStrategyTokensToEth(strategyTokensToWithdraw, deadline);
        uint256 fees = ethConverted.mul(_withdrawalFeeFraction).div(_withdrawalFeeBase);

        uint256 drcAmount = _convertEthToToken(ethConverted.sub(fees), drcAddress, deadline);

        SafeERC20.safeTransfer(IERC20(drcAddress), msg.sender, drcAmount);
        SafeERC20.safeTransfer(IERC20(uniswapRouter.WETH()), owner(), fees);

        emit Withdraw(msg.sender, drcAmount, fees, podToBurn, totalSupply(), totalTokenStored());
    }

    /**
     * @dev Get ETH worth of a certain amount of a token.
     * @param _amount Amount of token to convert.
     * @param _fromAddress Address of token to convert from.
     * @param _toAddress Address of token to convert to.
     * @param excludeFees If uniswap fees is considered.
     */
    function _getAAmountByBAmount(
        uint256 _amount,
        address _fromAddress,
        address _toAddress,
        bool excludeFees
    ) private view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = _fromAddress;
        path[1] = _toAddress;

        if (path[0] == path[1] || _amount == 0) {
            return _amount;
        }

        uint256 amountOut = uniswapRouter.getAmountsOut(_amount, path)[1];

        if (excludeFees) {
            return amountOut.mul(1000).div(997);
        } else {
            return amountOut;
        }
    }

    /**
     * @dev Get the worth in a token of a certain amount of ETH.
     * @param _amount Amount of ETH to convert.
     * @param _tokenAddress Address of the token to convert to.
     * @param excludeFees If uniswap fees is considered.
     */
    function _getTokenAmountByEthAmount(
        uint256 _amount,
        address _tokenAddress,
        bool excludeFees
    ) private view returns (uint256) {
        return _getAAmountByBAmount(_amount, uniswapRouter.WETH(), _tokenAddress, excludeFees);
    }

    /**
     * @dev Get ETH worth of a certain amount of a token.
     * @param _amount Amount of token to convert.
     * @param _tokenAddress Address of token to convert from.
     * @param excludeFees If uniswap fees is considered.
     */
    function _getEthAmountByTokenAmount(
        uint256 _amount,
        address _tokenAddress,
        bool excludeFees
    ) private view returns (uint256) {
        return _getAAmountByBAmount(_amount, _tokenAddress, uniswapRouter.WETH(), excludeFees);
    }

    /**
     * @dev Get ETH worth of an array of strategy tokens.
     * @param strategyTokensBalance_ Array amounts of strategy tokens to convert.
     * @param excludeFees If uniswap fees is considered.
     */
    function _getEthAmountByStrategyTokensAmount(
        uint256[] memory strategyTokensBalance_, 
        bool excludeFees
    ) private view returns (uint256) {
        uint256 amountOut;
        address[] memory path = new address[](2);
        path[1] = uniswapRouter.WETH();

        for (uint8 i = 0; i < _strategyTokenCount; i++) {
            address tokenAddress = _strategyTokens[i];
            path[0] = tokenAddress;
            uint256 tokenAmount = strategyTokensBalance_[i];
            uint256 tokenAmountInEth = _getEthAmountByTokenAmount(tokenAmount, tokenAddress, excludeFees);

            amountOut = amountOut.add(tokenAmountInEth);
        }
        return amountOut;
    }

    /**
     * @dev Get DR-POD worth in an array of strategy tokens.
     * @param _amount Amount of DR-POD to convert.
     */
    function _getStrategyTokensByPodAmount(uint256 _amount) private view returns (uint256[] memory) {
        uint256[] memory strategyTokenAmount = new uint256[](_strategyTokenCount);

        uint256 podFraction = _amount.mul(1e10).div(totalSupply());
        for (uint8 i = 0; i < _strategyTokenCount; i++) {
            strategyTokenAmount[i] = IERC20(_strategyTokens[i]).balanceOf(address(this)).mul(podFraction).div(1e10);
        }
        return strategyTokenAmount;
    }

    /**
     * @dev Convert a token to WETH via the Uniswap router.
     * @param _amount Amount of tokens to swap.
     * @param _tokenAddress Address of token to swap.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function _convertTokenToEth(
        uint256 _amount,
        address _tokenAddress,
        uint32 deadline
    ) private returns (uint256) {
        if (_tokenAddress == uniswapRouter.WETH() || _amount == 0) {
            return _amount;
        }
        address[] memory path = new address[](2);
        path[0] = _tokenAddress;
        path[1] = uniswapRouter.WETH();
        SafeERC20.safeApprove(IERC20(path[0]), router, _amount);
        uint256 amountOut = uniswapRouter.getAmountsOut(_amount, path)[1];
        uniswapRouter.swapExactTokensForTokens(_amount, amountOut, path, address(this), deadline);
        return amountOut;
    }

    /**
     * @dev Convert ETH to another token via the Uniswap router.
     * @param _amount Amount of WETH to swap.
     * @param _tokenAddress Address of token to swap to.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function _convertEthToToken(
        uint256 _amount,
        address _tokenAddress,
        uint32 deadline
    ) private returns (uint256) {
        if (_tokenAddress == uniswapRouter.WETH() || _amount == 0) {
            return _amount;
        }
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = _tokenAddress;
        SafeERC20.safeApprove(IERC20(path[0]), router, _amount);
        uint256 amountOut = uniswapRouter.getAmountsOut(_amount, path)[1];
        uniswapRouter.swapExactTokensForTokens(_amount, amountOut, path, address(this), deadline);
        return amountOut;
    }

    /**
     * @dev Convert ETH to strategy tokens of DR in their allocation percentage.
     * @param amount Amount of WETH to swap.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function _convertEthToStrategyTokens(
        uint256 amount, 
        uint32 deadline
    ) private returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](_strategyTokenCount);
        for (uint8 i = 0; i < _strategyTokenCount; i++) {
            uint256 amountToConvert = amount.mul(_tokenPercentage[_strategyTokens[i]]).div(100);
            amounts[i] = _convertEthToToken(amountToConvert, _strategyTokens[i], deadline);
        }
        return amounts;
    }

    /**
     * @dev Convert strategy tokens to WETH.
     * @param amountToConvert Array of the amounts of strategy tokens to swap.
     * @param deadline Unix timestamp after which the transaction will revert.
     */
    function _convertStrategyTokensToEth(
        uint256[] memory amountToConvert, 
        uint32 deadline
    ) private returns (uint256) {
        uint256 ethConverted;
        for (uint8 i = 0; i < _strategyTokenCount; i++) {
            uint256 amountConverted = _convertTokenToEth(amountToConvert[i], _strategyTokens[i], deadline);
            ethConverted = ethConverted.add(amountConverted);
        }
        return ethConverted;
    }
}