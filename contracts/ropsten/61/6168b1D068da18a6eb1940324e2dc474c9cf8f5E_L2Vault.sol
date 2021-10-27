// SPDX-License-Identifier: MIT

/**
 * Created on 2021-06-07 08:50
 * @summary: Vault for storing ERC20 tokens that will be transferred by external event-based system to another network. The destination network can be checked on "connectedNetwork"
 * @author: Composable Finance - Pepe Blasco
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "../interfaces/IComposableHolding.sol";
import "../interfaces/IComposableExchange.sol";
import "../interfaces/IReceiptBase.sol";
import "../interfaces/ITokenFactory.sol";
import "../interfaces/IL2VaultConfig.sol";
import "../interfaces/IWETH.sol";

import "../libraries/FeeOperations.sol";

//@title: Composable Finance L2 ERC20 Vault
contract L2Vault is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    mapping(uint256 => bool) public pausedNetwork;

    IL2VaultConfig public vaultConfig;
    IComposableHolding public composableHolding;

    mapping(bytes32 => bool) public hasBeenWithdrawn;
    mapping(bytes32 => bool) public hasBeenUnlocked;
    mapping(bytes32 => bool) public hasBeenRefunded;

    bytes32 public lastWithdrawID;
    bytes32 public lastUnlockID;
    bytes32 public lastRefundedID;

    struct DepositInfo {
        address token;
        uint256 amount;
    }
    mapping(bytes32 => DepositInfo) public deposits;

    mapping(address => uint256) public lastTransfer;
    /// @dev Store the address of the IOU token receipt

    event TransferInitiated(
        address indexed account,
        address indexed erc20,
        address remoteTokenAddress,
        uint256 indexed remoteNetworkID,
        uint256 value,
        address remoteDestinationAddress,
        bytes32 uniqueId,
        uint256 maxTransferDelay
    );

    event TransferToDifferentTokenInitiated(
        address owner,
        address indexed erc20,
        address tokenOut,
        address remoteTokenAddress,
        uint256 indexed remoteNetworkID,
        uint256 value,
        uint256 ammID,
        address remoteDestinationAddress,
        bytes32 uniqueId,
        uint256 maxTransferDelay
    );

    event WithdrawalCompleted(
        address indexed accountTo,
        uint256 amount,
        uint256 netAmount,
        address indexed tokenAddress,
        bytes32 indexed uniqueId
    );
    event LiquidityMoved(
        address indexed _owner,
        address indexed _to,
        uint256 amount
    );
    event TransferFundsRefunded(
        address indexed tokenAddress,
        address indexed user,
        uint256 amount,
        bytes32 uniqueId
    );
    event TransferFundsUnlocked(
        address indexed tokenAddress,
        uint256 amount,
        bytes32 uniqueId
    );

    event PauseNetwork(address admin, uint256 networkID);
    event UnpauseNetwork(address admin, uint256 networkID);
    event FeeTaken(
        address indexed _owner,
        address indexed _user,
        address indexed _token,
        uint256 _amount,
        uint256 _fee,
        uint256 baseFee,
        uint256 totalFee,
        bytes32 uniqueId
    );

    event DepositLiquidity(
        address indexed tokenAddress,
        address indexed provider,
        uint256 amount,
        uint256 blocks
    );

    event LiquidityWithdrawn(
        address indexed tokenAddress,
        address indexed provider,
        uint256 amount
    );

    event LiquidityRefunded(
        address indexed tokenAddress,
        address indexed user,
        uint256 amount,
        bytes32 uniqueId
    );

    event WithdrawOnRemoteNetworkStarted(
        address indexed account,
        address indexed erc20,
        address remoteTokenAddress,
        uint256 indexed remoteNetworkID,
        uint256 value,
        address remoteDestinationAddress,
        bytes32 uniqueId
    );

    event WithdrawOnRemoteNetworkForDifferentTokenStarted(
        address indexed account,
        address indexed remoteTokenAddress,
        uint256 indexed remoteNetworkID,
        uint256 value,
        uint256 amountOutMin,
        address remoteDestinationAddress,
        uint256 remoteAmmId,
        bytes32 uniqueId
    );

    function initialize(address _vaultConfig) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        vaultConfig = IL2VaultConfig(_vaultConfig);
        composableHolding = IComposableHolding(
            vaultConfig.getComposableHolding()
        );
    }

    /// @notice External callable function to pause the contract
    function pauseNetwork(uint256 networkID) external onlyOwner {
        pausedNetwork[networkID] = true;
        emit PauseNetwork(msg.sender, networkID);
    }

    /// @notice External callable function to unpause the contract
    function unpauseNetwork(uint256 networkID) external onlyOwner {
        pausedNetwork[networkID] = false;
        emit UnpauseNetwork(msg.sender, networkID);
    }

    // @notice transfer ERC20 token to another l2 vault
    // @param amount amount of tokens to deposit
    // @param tokenAddress  SC address of the ERC20 token to deposit
    // @param maxTransferDelay delay in seconds for the relayer to execute the transaction
    function transferERC20ToLayer(
        uint256 amount,
        address tokenAddress,
        address remoteDestinationAddress,
        uint256 remoteNetworkID,
        uint256 maxTransferDelay
    )
        external
        validAmount(amount)
        onlyWhitelistedRemoteTokens(remoteNetworkID, tokenAddress)
        nonReentrant
        whenNotPausedNetwork(remoteNetworkID)
    {
        bytes32 id = vaultConfig.generateId();
        _transferERC20ToLayer(tokenAddress, amount, id);

        emit TransferInitiated(
            msg.sender,
            tokenAddress,
            vaultConfig.remoteTokenAddress(remoteNetworkID, tokenAddress),
            remoteNetworkID,
            amount,
            remoteDestinationAddress,
            id,
            maxTransferDelay
        );
    }

    // @notice transfer ERC20 token to another l2 vault
    // @param amount amount of tokens to deposit
    // @param tokenAddress  SC address of the ERC20 token to deposit
    // @param maxTransferDelay delay in seconds for the relayer to execute the transaction
    // @param tokenOut  SC address of the ERC20 token to receive tokens
    // @param remoteAmmId remote integer constant for the AMM
    function transferERC20ToLayerForDifferentToken(
        uint256 amount,
        address tokenAddress,
        address remoteDestinationAddress,
        uint256 remoteNetworkID,
        uint256 maxTransferDelay,
        address tokenOut,
        uint256 remoteAmmId
    ) external nonReentrant whenNotPausedNetwork(remoteNetworkID) {
        require(amount > 0, "Invalid amount");
        address remoteTokenAddress = vaultConfig.remoteTokenAddress(
            remoteNetworkID,
            tokenAddress
        );
        require(
            remoteTokenAddress != address(0),
            "token not whitelisted in this network"
        );
        bytes32 id = vaultConfig.generateId();
        _transferERC20ToLayer(tokenAddress, amount, id);

        emit TransferToDifferentTokenInitiated(
            msg.sender,
            tokenAddress,
            tokenOut,
            remoteTokenAddress,
            remoteNetworkID,
            amount,
            remoteAmmId,
            remoteDestinationAddress,
            id,
            maxTransferDelay
        );
    }

    function _transferERC20ToLayer(
        address tokenAddress,
        uint256 amount,
        bytes32 id
    ) private inTokenTransferLimits(tokenAddress, amount) {
        require(
            lastTransfer[msg.sender].add(vaultConfig.transferLockupTime()) <
                block.timestamp,
            "Transfer not yet possible"
        );
        IERC20Upgradeable(tokenAddress).safeTransferFrom(
            msg.sender,
            address(composableHolding),
            amount
        );

        deposits[id] = DepositInfo({token: tokenAddress, amount: amount});

        vaultConfig.setLockedTransferFunds(
            tokenAddress,
            vaultConfig.transferLockupTime().add(amount)
        );

        lastTransfer[msg.sender] = block.timestamp;
    }

    function provideLiquidity(
        uint256 amount,
        address tokenAddress,
        uint256 blocksForActiveLiquidity
    )
        external
        validAddress(tokenAddress)
        validAmount(amount)
        onlyWhitelistedToken(tokenAddress)
        nonReentrant
        whenNotPaused
    {
        require(
            blocksForActiveLiquidity >= vaultConfig.minLimitLiquidityBlocks() &&
                blocksForActiveLiquidity <=
                vaultConfig.maxLimitLiquidityBlocks(),
            "not within block approve range"
        );
        IERC20Upgradeable(tokenAddress).safeTransferFrom(
            msg.sender,
            address(composableHolding),
            amount
        );
        IReceiptBase(vaultConfig.getUnderlyingReceiptAddress(tokenAddress))
            .mint(msg.sender, amount);
        emit DepositLiquidity(
            tokenAddress,
            msg.sender,
            amount,
            blocksForActiveLiquidity
        );
    }

    function provideEthLiquidity(uint256 blocksForActiveLiquidity)
        external
        payable
        whenNotPaused
        nonReentrant
        validAmount(msg.value)
    {
        require(
            blocksForActiveLiquidity >= vaultConfig.minLimitLiquidityBlocks() &&
                blocksForActiveLiquidity <=
                vaultConfig.maxLimitLiquidityBlocks(),
            "not within block approve range"
        );

        address weth = vaultConfig.wethAddress();

        require(weth != address(0), "WETH not set");
        IWETH(weth).deposit{value: msg.value}();

        IReceiptBase(vaultConfig.getUnderlyingReceiptAddress(weth)).mint(
            msg.sender,
            msg.value
        );

        emit DepositLiquidity(
            weth,
            msg.sender,
            msg.value,
            blocksForActiveLiquidity
        );
    }

    function withdrawLiquidity(address tokenAddress, uint256 amount)
        external
        validAddress(tokenAddress)
        validAmount(amount)
        enoughLiquidityInVault(tokenAddress, amount)
    {
        _burnIOUTokens(tokenAddress, msg.sender, amount);

        composableHolding.transfer(tokenAddress, msg.sender, amount);
        emit LiquidityWithdrawn(tokenAddress, msg.sender, amount);
    }

    // @notice called by the relayer to restore the user's liquidity
    //         when `withdrawDifferentTokenTo` fails on the destination layer
    // @param _user address of the user account
    // @param _amount amount of tokens
    // @param _tokenAddress  address of the ERC20 token
    // @param _id the id generated by the withdraw method call by the user
    function refundLiquidity(
        address _user,
        uint256 _amount,
        address _tokenAddress,
        bytes32 _id
    )
        external
        onlyOwner
        validAmount(_amount)
        enoughLiquidityInVault(_tokenAddress, _amount)
        nonReentrant
    {
        require(hasBeenRefunded[_id] == false, "Already refunded");

        hasBeenRefunded[_id] = true;
        lastRefundedID = _id;

        IReceiptBase(vaultConfig.getUnderlyingReceiptAddress(_tokenAddress))
            .mint(_user, _amount);

        emit LiquidityRefunded(_tokenAddress, _user, _amount, _id);
    }

    /// @notice External function called to withdraw liquidity in different token
    /// @param tokenIn Address of the token provider have
    /// @param tokenOut Address of the token provider want to receive
    /// @param amountIn Amount of tokens provider want to withdraw
    /// @param amountOutMin Minimum amount of token user should get
    function withdrawLiquidityToDifferentToken(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 ammID,
        bytes calldata data
    )
        external
        validAmount(amountIn)
        onlyWhitelistedToken(tokenOut)
        onlyWhitelistedToken(tokenIn)
        differentAddresses(tokenIn, tokenOut)
        isAMMSupported(ammID)
    {
        _burnIOUTokens(tokenIn, msg.sender, amountIn);
        composableHolding.transfer(tokenIn, address(this), amountIn);
        IERC20Upgradeable(tokenIn).safeApprove(
            vaultConfig.getAMMAddress(ammID),
            amountIn
        );
        uint256 amountToSend = IComposableExchange(
            vaultConfig.getAMMAddress(ammID)
        ).swap(tokenIn, tokenOut, amountIn, amountOutMin, data);
        IERC20Upgradeable(tokenOut).safeTransfer(msg.sender, amountToSend);
        emit LiquidityWithdrawn(tokenOut, msg.sender, amountToSend);
    }

    function withdrawLiquidityOnAnotherL2Network(
        address tokenAddress,
        uint256 amount,
        address remoteDestinationAddress,
        uint256 _networkID
    )
        external
        validAddress(tokenAddress)
        validAmount(amount)
        onlyWhitelistedRemoteTokens(_networkID, tokenAddress)
    {
        _burnIOUTokens(tokenAddress, msg.sender, amount);

        emit WithdrawOnRemoteNetworkStarted(
            msg.sender,
            tokenAddress,
            vaultConfig.remoteTokenAddress(_networkID, tokenAddress),
            _networkID,
            amount,
            remoteDestinationAddress,
            vaultConfig.generateId()
        );
    }

    /// @notice External function called to withdraw liquidity in different token on another network
    /// @param tokenIn Address of the token provider have
    /// @param tokenOut Address of the token provider want to receive
    /// @param amountIn Amount of tokens provider want to withdraw
    /// @param networkID Id of the network want to receive the other token
    /// @param amountOutMin Minimum amount of token user should get
    function withdrawLiquidityToDifferentTokenOnAnotherL2Network(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 networkID,
        uint256 amountOutMin,
        address remoteDestinationAddress,
        uint256 remoteAmmId
    )
        external
        validAmount(amountIn)
        onlyWhitelistedToken(tokenOut)
        onlyWhitelistedToken(tokenIn)
        onlyWhitelistedRemoteTokens(networkID, tokenOut)
    {
        _withdrawToNetworkInDifferentToken(
            tokenIn,
            tokenOut,
            amountIn,
            networkID,
            amountOutMin,
            remoteDestinationAddress,
            remoteAmmId
        );
    }

    /// @dev internal function to withdraw different token on another network
    /// @dev use this approach to avoid stack too deep error
    function _withdrawToNetworkInDifferentToken(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 networkID,
        uint256 amountOutMin,
        address remoteDestinationAddress,
        uint256 remoteAmmId
    ) internal differentAddresses(tokenIn, tokenOut) {
        _burnIOUTokens(tokenIn, msg.sender, amountIn);

        emit WithdrawOnRemoteNetworkForDifferentTokenStarted(
            msg.sender,
            vaultConfig.remoteTokenAddress(networkID, tokenOut),
            networkID,
            amountIn,
            amountOutMin,
            remoteDestinationAddress,
            remoteAmmId,
            vaultConfig.generateId()
        );
    }

    function _burnIOUTokens(
        address tokenAddress,
        address provider,
        uint256 amount
    ) internal {
        IReceiptBase receipt = IReceiptBase(
            vaultConfig.getUnderlyingReceiptAddress(tokenAddress)
        );
        require(
            receipt.balanceOf(provider) >= amount,
            "IOU Token balance to low"
        );
        receipt.burn(provider, amount);
    }

    // @notice: method called by the relayer to release funds
    // @param accountTo eth address to send the withdrawal tokens
    function withdrawTo(
        address accountTo,
        uint256 amount,
        address tokenAddress,
        bytes32 id,
        uint256 baseFee
    )
        external
        onlyWhitelistedToken(tokenAddress)
        enoughLiquidityInVault(tokenAddress, amount)
        nonReentrant
        onlyOwner
        whenNotPaused
        notAlreadyWithdrawn(id)
    {
        _withdraw(
            accountTo,
            amount,
            tokenAddress,
            address(0),
            id,
            baseFee,
            0,
            0,
            ""
        );
    }

    // @notice: method called by the relayer to release funds in different token
    // @param accountTo eth address to send the withdrawal tokens
    // @param amount amount of token in
    // @param tokenIn address of the token in
    // @param tokenOut address of the token out
    // @param id withdrawal id
    // @param baseFee the fee taken by the relayer
    // @param amountOutMin minimum amount out user want
    // @param data additional data required for each AMM implementation
    function withdrawDifferentTokenTo(
        address accountTo,
        uint256 amount,
        address tokenIn,
        address tokenOut,
        bytes32 id,
        uint256 baseFee,
        uint256 amountOutMin,
        uint256 ammID,
        bytes calldata data
    )
        external
        onlyWhitelistedToken(tokenIn)
        nonReentrant
        onlyOwner
        whenNotPaused
        notAlreadyWithdrawn(id)
    {
        _withdraw(
            accountTo,
            amount,
            tokenIn,
            tokenOut,
            id,
            baseFee,
            amountOutMin,
            ammID,
            data
        );
    }

    function _withdraw(
        address accountTo,
        uint256 amount,
        address tokenIn,
        address tokenOut,
        bytes32 id,
        uint256 baseFee,
        uint256 amountOutMin,
        uint256 ammID,
        bytes memory data
    ) private {
        hasBeenWithdrawn[id] = true;
        lastWithdrawID = id;
        uint256 withdrawAmount = _takeFees(
            tokenIn,
            amount,
            accountTo,
            id,
            baseFee
        );

        if (tokenOut == address(0)) {
            composableHolding.transfer(tokenIn, accountTo, withdrawAmount);
        } else {
            require(
                vaultConfig.getAMMAddress(ammID) != address(0),
                "AMM not supported"
            );
            composableHolding.transfer(tokenIn, address(this), withdrawAmount);
            IERC20Upgradeable(tokenIn).safeApprove(
                vaultConfig.getAMMAddress(ammID),
                withdrawAmount
            );
            uint256 amountToSend = IComposableExchange(
                vaultConfig.getAMMAddress(ammID)
            ).swap(tokenIn, tokenOut, withdrawAmount, amountOutMin, data);
            require(amountToSend >= amountOutMin, "AMM: Price to low");
            IERC20Upgradeable(tokenOut).safeTransfer(accountTo, amountToSend);
        }

        emit WithdrawalCompleted(
            accountTo,
            amount,
            withdrawAmount,
            tokenIn,
            id
        );
    }

    function _takeFees(
        address token,
        uint256 amount,
        address accountTo,
        bytes32 withdrawRequestId,
        uint256 baseFee
    ) private returns (uint256) {
        uint256 feePercentage = vaultConfig.calculateFeePercentage(
            token,
            amount
        );
        uint256 fee = FeeOperations.getFeeAbsolute(amount, feePercentage);
        uint256 withdrawAmount = amount.sub(fee);

        if (baseFee > 0) {
            composableHolding.transfer(token, owner(), baseFee);
        }

        if (fee > 0) {
            composableHolding.transfer(token, vaultConfig.feeAddress(), fee);
        }

        if (baseFee + fee > 0) {
            emit FeeTaken(
                msg.sender,
                accountTo,
                token,
                amount,
                fee,
                baseFee,
                fee + baseFee,
                withdrawRequestId
            );
        }

        return withdrawAmount;
    }

    /**
     * @notice Will be called once the contract is paused and token's available liquidity will be manually moved back to L1
     * @param _token Token's balance the owner wants to withdraw
     * @param _to Receiver address
     */
    function saveFunds(address _token, address _to)
        external
        onlyOwner
        whenPaused
        validAddress(_token)
        validAddress(_to)
    {
        uint256 balance = IERC20Upgradeable(_token).balanceOf(
            address(composableHolding)
        );
        require(balance > 0, "nothing to transfer");
        composableHolding.transfer(_token, _to, balance);
        emit LiquidityMoved(msg.sender, _to, balance);
    }

    /**
     * @notice The idea is to be able to withdraw to a controlled address certain amount of
               token liquidity in order to re-balance among different L2s (manual bridge to L1
               and then act accordingly)
     * @param _token Token's balance the owner wants to withdraw
     * @param _to Receiver address
     * @param _amount the amount of tokens to withdraw from the vault
     */
    function withdrawFunds(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner validAddress(_token) validAddress(_to) {
        uint256 tokenLiquidity = vaultConfig.getCurrentTokenLiquidity(_token);
        require(
            tokenLiquidity >= _amount,
            "withdrawFunds: vault balance is low"
        );
        composableHolding.transfer(_token, _to, _amount);
        emit LiquidityMoved(msg.sender, _to, _amount);
    }

    /*
    this method is called by the relayer after a successful transfer of tokens between layers
    this is called to unlock the funds to be added in the liquidity of the vault
    */
    function unlockTransferFunds(
        address _token,
        uint256 _amount,
        bytes32 _id
    ) public whenNotPaused onlyOwner {
        require(hasBeenUnlocked[_id] == false, "Already unlocked");
        require(
            vaultConfig.lockedTransferFunds(_token) >= _amount,
            "More amount than available"
        );

        require(
            deposits[_id].token == _token && deposits[_id].amount == _amount,
            "Registered deposit data does not match provided"
        );

        hasBeenUnlocked[_id] = true;
        lastUnlockID = _id;

        // update the lockedTransferFunds for the token
        vaultConfig.setLockedTransferFunds(
            _token,
            vaultConfig.lockedTransferFunds(_token).sub(_amount)
        );

        emit TransferFundsUnlocked(_token, _amount, _id);
    }

    /*
    called by the relayer to return the tokens back to user in case of a failed
    transfer between layers. this method will mark the `id` as used and emit
    the event that funds has been claimed by the user
    */
    function refundTransferFunds(
        address _token,
        address _user,
        uint256 _amount,
        bytes32 _id
    ) external onlyOwner nonReentrant {
        require(hasBeenRefunded[_id] == false, "Already refunded");

        // unlock the funds
        if (hasBeenUnlocked[_id] == false) {
            unlockTransferFunds(_token, _amount, _id);
        }

        hasBeenRefunded[_id] = true;
        lastRefundedID = _id;

        composableHolding.transfer(_token, _user, _amount);

        delete deposits[_id];

        emit TransferFundsRefunded(_token, _user, _amount, _id);
    }

    function getRemoteTokenAddress(uint256 _networkID, address _tokenAddress)
        external
        view
        returns (address tokenAddressRemote)
    {
        tokenAddressRemote = vaultConfig.remoteTokenAddress(
            _networkID,
            _tokenAddress
        );
    }

    /// @notice External callable function to pause the contract
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /// @notice External callable function to unpause the contract
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier validAmount(uint256 _value) {
        require(_value > 0, "Invalid amount");
        _;
    }

    modifier onlyWhitelistedToken(address tokenAddress) {
        require(
            vaultConfig.getUnderlyingReceiptAddress(tokenAddress) != address(0),
            "token not whitelisted"
        );
        _;
    }

    modifier onlyWhitelistedRemoteTokens(
        uint256 networkID,
        address tokenAddress
    ) {
        require(
            vaultConfig.remoteTokenAddress(networkID, tokenAddress) !=
                address(0),
            "token not whitelisted in this network"
        );
        _;
    }

    modifier whenNotPausedNetwork(uint256 networkID) {
        require(paused() == false, "Contract is paused");
        require(pausedNetwork[networkID] == false, "Network is paused");
        _;
    }

    modifier differentAddresses(
        address tokenAddress,
        address tokenAddressReceive
    ) {
        require(tokenAddress != tokenAddressReceive, "Same token address");
        _;
    }

    modifier isAMMSupported(uint256 ammID) {
        require(
            vaultConfig.getAMMAddress(ammID) != address(0),
            "AMM not supported"
        );
        _;
    }

    modifier enoughLiquidityInVault(address tokenAddress, uint256 amount) {
        require(
            vaultConfig.getCurrentTokenLiquidity(tokenAddress) >= amount,
            "Not enough tokens in the vault"
        );
        _;
    }

    modifier notAlreadyWithdrawn(bytes32 id) {
        require(hasBeenWithdrawn[id] == false, "Already withdrawn");
        _;
    }

    modifier inTokenTransferLimits(address token, uint256 amount) {
        require(
            vaultConfig.inTokenTransferLimits(token, amount),
            "Amount out of token transfer limits"
        );
        _;
    }
}