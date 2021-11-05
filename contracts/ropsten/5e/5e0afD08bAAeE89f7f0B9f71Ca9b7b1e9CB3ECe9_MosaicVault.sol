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

import "../interfaces/IComposableHolding.sol";
import "../interfaces/IComposableExchange.sol";
import "../interfaces/IReceiptBase.sol";
import "../interfaces/ITokenFactory.sol";
import "../interfaces/IMosaicVaultConfig.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IMosaicVault.sol";

import "../libraries/FeeOperations.sol";

//@title: Composable Finance Mosaic ERC20 Vault
contract MosaicVault is
    IMosaicVault,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    mapping(uint256 => bool) public pausedNetwork;

    mapping(bytes32 => bool) public hasBeenWithdrawn;

    mapping(bytes32 => bool) public hasBeenUnlocked;

    mapping(bytes32 => bool) public hasBeenRefunded;

    /// @dev mapping userAddress => tokenAddress => availableAfterBlock
    mapping(address => mapping(address => uint256)) private availableAfterBlock;

    mapping(bytes32 => DepositInfo) public deposits;

    mapping(address => uint256) public lastTransfer;

    bytes32 public lastWithdrawID;
    bytes32 public lastUnlockID;
    bytes32 public lastRefundedID;

    uint256 public saveFundsTimer;
    uint256 public saveFundsAmount;
    uint256 public saveFundsLockupTime;
    uint256 public durationToChangeTimer;
    uint256 public newSaveFundsLockUpTime;

    address public relayer;
    address public tokenAddressToSaveFunds;
    address public userAddressToSaveFundsTo;

    IMosaicVaultConfig public vaultConfig;

    struct DepositInfo {
        address token;
        uint256 amount;
    }

    function initialize(address _mosaicVaultConfig) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        vaultConfig = IMosaicVaultConfig(_mosaicVaultConfig);

        saveFundsLockupTime = 12 hours;
    }

    /// @notice External callable function to set the relayer address
    function setRelayer(address _relayer) external override onlyOwner {
        relayer = _relayer;
    }

    /// @notice External callable function to set the vault config address
    function setVaultConfig(address _vaultConfig) external override onlyOwner {
        vaultConfig = IMosaicVaultConfig(_vaultConfig);
    }

    /// @notice External callable function to pause the contract
    function pauseNetwork(uint256 _networkID) external override onlyOwner {
        pausedNetwork[_networkID] = true;
        emit PauseNetwork(msg.sender, _networkID);
    }

    /// @notice External callable function to unpause the contract
    function unpauseNetwork(uint256 _networkID) external override onlyOwner {
        pausedNetwork[_networkID] = false;
        emit UnpauseNetwork(msg.sender, _networkID);
    }

    // @notice transfer ERC20 token to another Mosaic vault
    /// @param _amount amount of tokens to deposit
    /// @param _tokenAddress  SC address of the ERC20 token to deposit
    /// @param _maxTransferDelay delay in seconds for the relayer to execute the transaction
    function transferERC20ToLayer(
        uint256 _amount,
        address _tokenAddress,
        address _remoteDestinationAddress,
        uint256 _remoteNetworkID,
        uint256 _maxTransferDelay
    )
        external
        override
        validAmount(_amount)
        onlyWhitelistedRemoteTokens(_remoteNetworkID, _tokenAddress)
        nonReentrant
        whenNotPausedNetwork(_remoteNetworkID)
    {
        bytes32 id = vaultConfig.generateId();
        _transferERC20ToLayer(_tokenAddress, _amount, id);

        emit TransferInitiated(
            msg.sender,
            _tokenAddress,
            vaultConfig.remoteTokenAddress(_remoteNetworkID, _tokenAddress),
            _remoteNetworkID,
            _amount,
            _remoteDestinationAddress,
            id,
            _maxTransferDelay
        );
    }

    // @notice transfer ERC20 token to another Mosaic vault
    /// @param _amount amount of tokens to deposit
    /// @param _tokenAddress  SC address of the ERC20 token to deposit
    /// @param _maxTransferDelay delay in seconds for the relayer to execute the transaction
    /// @param _tokenOut  SC address of the ERC20 token to receive tokens
    /// @param _remoteAmmId remote integer constant for the AMM
    function transferERC20ToLayerForDifferentToken(
        uint256 _amount,
        address _tokenAddress,
        address _remoteDestinationAddress,
        uint256 _remoteNetworkID,
        uint256 _maxTransferDelay,
        address _tokenOut,
        uint256 _remoteAmmId
    ) external override nonReentrant whenNotPausedNetwork(_remoteNetworkID) {
        require(_amount > 0, "Invalid amount");
        address remoteTokenAddress = vaultConfig.remoteTokenAddress(
            _remoteNetworkID,
            _tokenAddress
        );
        require(
            remoteTokenAddress != address(0),
            "token not whitelisted in this network"
        );
        bytes32 id = vaultConfig.generateId();
        _transferERC20ToLayer(_tokenAddress, _amount, id);

        emit TransferToDifferentTokenInitiated(
            msg.sender,
            _tokenAddress,
            _tokenOut,
            remoteTokenAddress,
            _remoteNetworkID,
            _amount,
            _remoteAmmId,
            _remoteDestinationAddress,
            id,
            _maxTransferDelay
        );
    }

    function _transferERC20ToLayer(
        address _tokenAddress,
        uint256 _amount,
        bytes32 _id
    ) private inTokenTransferLimits(_tokenAddress, _amount) {
        require(
            lastTransfer[msg.sender] + vaultConfig.transferLockupTime() <
                block.timestamp,
            "Transfer not yet possible"
        );
        IERC20Upgradeable(_tokenAddress).safeTransferFrom(
            msg.sender,
            vaultConfig.getComposableHolding(),
            _amount
        );

        deposits[_id] = DepositInfo({token: _tokenAddress, amount: _amount});

        vaultConfig.setLockedTransferFunds(
            _tokenAddress,
            vaultConfig.transferLockupTime() + _amount
        );

        lastTransfer[msg.sender] = block.timestamp;
    }

    function provideLiquidity(
        uint256 _amount,
        address _tokenAddress,
        uint256 _blocksForActiveLiquidity
    )
        external
        override
        validAddress(_tokenAddress)
        validAmount(_amount)
        onlyWhitelistedToken(_tokenAddress)
        nonReentrant
        whenNotPaused
    {
        require(
            _blocksForActiveLiquidity >=
                vaultConfig.minLimitLiquidityBlocks() &&
                _blocksForActiveLiquidity <=
                vaultConfig.maxLimitLiquidityBlocks(),
            "not within block approve range"
        );
        IERC20Upgradeable(_tokenAddress).safeTransferFrom(
            msg.sender,
            vaultConfig.getComposableHolding(),
            _amount
        );
        IReceiptBase(vaultConfig.getUnderlyingIOUAddress(_tokenAddress)).mint(
            msg.sender,
            _amount
        );
        _updateAvailableTokenAfter(_tokenAddress, _blocksForActiveLiquidity);
        emit DepositLiquidity(
            _tokenAddress,
            msg.sender,
            _amount,
            _blocksForActiveLiquidity
        );
    }

    function provideEthLiquidity(uint256 _blocksForActiveLiquidity)
        public
        payable
        whenNotPaused
        nonReentrant
        validAmount(msg.value)
    {
        require(
            _blocksForActiveLiquidity >=
                vaultConfig.minLimitLiquidityBlocks() &&
                _blocksForActiveLiquidity <=
                vaultConfig.maxLimitLiquidityBlocks(),
            "not within block approve range"
        );

        address weth = vaultConfig.wethAddress();

        require(weth != address(0), "WETH not set");
        IWETH(weth).deposit{value: msg.value}();

        IReceiptBase(vaultConfig.getUnderlyingIOUAddress(weth)).mint(
            msg.sender,
            msg.value
        );
        _updateAvailableTokenAfter(weth, _blocksForActiveLiquidity);
        emit DepositLiquidity(
            weth,
            msg.sender,
            msg.value,
            _blocksForActiveLiquidity
        );
    }

    function addLiquidityWithdrawRequest(address _tokenAddress, uint256 _amount)
        external
        override
        validAddress(_tokenAddress)
        validAmount(_amount)
        enoughLiquidityInVault(_tokenAddress, _amount)
        availableToWithdrawLiquidity(_tokenAddress)
    {
        _burnIOUTokens(_tokenAddress, msg.sender, _amount);
        emit WithdrawRequest(
            msg.sender,
            _tokenAddress,
            _tokenAddress,
            _amount,
            block.chainid
        );
    }

    function withdrawLiquidity(
        address _receiver,
        address _tokenAddress,
        uint256 _amount
    ) external override onlyOwnerOrRelayer {
        IComposableHolding(vaultConfig.getComposableHolding()).transfer(
            _tokenAddress,
            _receiver,
            _amount
        );
        emit LiquidityWithdrawn(_tokenAddress, _receiver, _amount);
    }

    // @notice called by the relayer to restore the user's liquidity
    //         when `withdrawDifferentTokenTo` fails on the destination layer
    /// @param _user address of the user account
    /// @param _amount amount of tokens
    /// @param _tokenAddress  address of the ERC20 token
    /// @param _id the id generated by the withdraw method call by the user
    function refundLiquidity(
        address _user,
        uint256 _amount,
        address _tokenAddress,
        bytes32 _id
    )
        external
        override
        onlyOwnerOrRelayer
        validAmount(_amount)
        enoughLiquidityInVault(_tokenAddress, _amount)
        nonReentrant
    {
        require(hasBeenRefunded[_id] == false, "Already refunded");

        hasBeenRefunded[_id] = true;
        lastRefundedID = _id;

        IReceiptBase(vaultConfig.getUnderlyingIOUAddress(_tokenAddress)).mint(
            _user,
            _amount
        );

        emit LiquidityRefunded(_tokenAddress, _user, _amount, _id);
    }

    /// @notice External function called to add withdraw liquidity request in different token
    /// @param _tokenIn Address of the token provider have
    /// @param _tokenOut Address of the token provider want to receive
    /// @param _amountIn Amount of tokens provider want to withdraw
    /// @param _amountOutMin Minimum amount of token user should get
    function addWithdrawLiquidityToDifferentTokenRequest(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        uint256 _ammID,
        bytes calldata _data
    )
        external
        override
        onlyWhitelistedToken(_tokenOut)
        onlyWhitelistedToken(_tokenIn)
        differentAddresses(_tokenIn, _tokenOut)
        availableToWithdrawLiquidity(_tokenIn)
    {
        _burnIOUTokens(_tokenIn, msg.sender, _amountIn);
        emit WithdrawRequest(
            msg.sender,
            _tokenOut,
            _tokenIn,
            _swap(_amountIn, _amountOutMin, _tokenIn, _tokenOut, _ammID, _data),
            block.chainid
        );
    }

    function withdrawLiquidityOnAnotherMosaicNetwork(
        address _tokenAddress,
        uint256 _amount,
        address _remoteDestinationAddress,
        uint256 _networkID
    )
        external
        override
        validAddress(_tokenAddress)
        validAmount(_amount)
        onlyWhitelistedRemoteTokens(_networkID, _tokenAddress)
        availableToWithdrawLiquidity(_tokenAddress)
    {
        _burnIOUTokens(_tokenAddress, msg.sender, _amount);

        emit WithdrawOnRemoteNetworkStarted(
            msg.sender,
            _tokenAddress,
            vaultConfig.remoteTokenAddress(_networkID, _tokenAddress),
            _networkID,
            _amount,
            _remoteDestinationAddress,
            vaultConfig.generateId()
        );
    }

    /// @notice External function called to withdraw liquidity in different token on another network
    /// @param _tokenIn Address of the token provider have
    /// @param _tokenOut Address of the token provider want to receive
    /// @param _amountIn Amount of tokens provider want to withdraw
    /// @param _networkID Id of the network want to receive the other token
    /// @param _amountOutMin Minimum amount of token user should get
    function withdrawLiquidityToDifferentTokenOnAnotherMosaicNetwork(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _networkID,
        uint256 _amountOutMin,
        address _remoteDestinationAddress,
        uint256 _remoteAmmId
    )
        external
        override
        validAmount(_amountIn)
        onlyWhitelistedToken(_tokenOut)
        onlyWhitelistedToken(_tokenIn)
        onlyWhitelistedRemoteTokens(_networkID, _tokenOut)
        availableToWithdrawLiquidity(_tokenIn)
    {
        _withdrawToNetworkInDifferentToken(
            _tokenIn,
            _tokenOut,
            _amountIn,
            _networkID,
            _amountOutMin,
            _remoteDestinationAddress,
            _remoteAmmId
        );
    }

    /// @dev internal function to withdraw different token on another network
    /// @dev use this approach to avoid stack too deep error
    function _withdrawToNetworkInDifferentToken(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _networkID,
        uint256 _amountOutMin,
        address _remoteDestinationAddress,
        uint256 _remoteAmmId
    ) internal differentAddresses(_tokenIn, _tokenOut) {
        _burnIOUTokens(_tokenIn, msg.sender, _amountIn);

        emit WithdrawOnRemoteNetworkForDifferentTokenStarted(
            msg.sender,
            vaultConfig.remoteTokenAddress(_networkID, _tokenOut),
            _networkID,
            _amountIn,
            _amountOutMin,
            _remoteDestinationAddress,
            _remoteAmmId,
            vaultConfig.generateId()
        );
    }

    function _burnIOUTokens(
        address _tokenAddress,
        address _provider,
        uint256 _amount
    ) internal validAmount(_amount) {
        IReceiptBase receipt = IReceiptBase(
            vaultConfig.getUnderlyingIOUAddress(_tokenAddress)
        );
        require(
            receipt.balanceOf(_provider) >= _amount,
            "IOU Token balance to low"
        );
        receipt.burn(_provider, _amount);
    }

    // @notice: method called by the relayer to release funds
    /// @param _accountTo eth address to send the withdrawal tokens
    function withdrawTo(
        address _accountTo,
        uint256 _amount,
        address _tokenAddress,
        bytes32 _id,
        uint256 _baseFee
    )
        external
        override
        onlyWhitelistedToken(_tokenAddress)
        enoughLiquidityInVault(_tokenAddress, _amount)
        nonReentrant
        onlyOwnerOrRelayer
        whenNotPaused
        notAlreadyWithdrawn(_id)
    {
        _withdraw(
            _accountTo,
            _amount,
            _tokenAddress,
            address(0),
            _id,
            _baseFee,
            0,
            0,
            ""
        );
    }

    // @notice: method called by the relayer to release funds in different token
    /// @param _accountTo eth address to send the withdrawal tokens
    /// @param _amount amount of token in
    /// @param _tokenIn address of the token in
    /// @param _tokenOut address of the token out
    /// @param _id withdrawal _id
    /// @param _baseFee the fee taken by the relayer
    /// @param _amountOutMin minimum amount out user want
    /// @param _data additional _data required for each AMM implementation
    function withdrawDifferentTokenTo(
        address _accountTo,
        uint256 _amount,
        address _tokenIn,
        address _tokenOut,
        bytes32 _id,
        uint256 _baseFee,
        uint256 _amountOutMin,
        uint256 _ammID,
        bytes calldata _data
    )
        external
        override
        onlyWhitelistedToken(_tokenIn)
        nonReentrant
        onlyOwnerOrRelayer
        whenNotPaused
        notAlreadyWithdrawn(_id)
    {
        _withdraw(
            _accountTo,
            _amount,
            _tokenIn,
            _tokenOut,
            _id,
            _baseFee,
            _amountOutMin,
            _ammID,
            _data
        );
    }

    function _withdraw(
        address _accountTo,
        uint256 _amount,
        address _tokenIn,
        address _tokenOut,
        bytes32 _id,
        uint256 _baseFee,
        uint256 _amountOutMin,
        uint256 _ammID,
        bytes memory _data
    ) private {
        hasBeenWithdrawn[_id] = true;
        lastWithdrawID = _id;
        uint256 withdrawAmount = _takeFees(
            _tokenIn,
            _amount,
            _accountTo,
            _id,
            _baseFee
        );

        IComposableHolding composableHolding = IComposableHolding(
            vaultConfig.getComposableHolding()
        );
        if (_tokenOut == address(0)) {
            composableHolding.transfer(_tokenIn, _accountTo, withdrawAmount);
        } else {
            uint256 amountToSend = _swap(
                withdrawAmount,
                _amountOutMin,
                _tokenIn,
                _tokenOut,
                _ammID,
                _data
            );
            composableHolding.transfer(_tokenOut, _accountTo, amountToSend);
        }

        emit WithdrawalCompleted(
            _accountTo,
            _amount,
            withdrawAmount,
            _tokenIn,
            _id
        );
    }

    function _takeFees(
        address _token,
        uint256 _amount,
        address _accountTo,
        bytes32 _withdrawRequestId,
        uint256 _baseFee
    ) private returns (uint256) {
        uint256 feePercentage = vaultConfig.calculateFeePercentage(
            _token,
            _amount
        );

        uint256 fee = FeeOperations.getFeeAbsolute(_amount, feePercentage);
        uint256 withdrawAmount = _amount - fee;

        if (_baseFee > 0) {
            IComposableHolding(vaultConfig.getComposableHolding()).transfer(
                _token,
                owner(),
                _baseFee
            );
        }

        if (fee > 0) {
            IComposableHolding(vaultConfig.getComposableHolding()).transfer(
                _token,
                vaultConfig.feeAddress(),
                fee
            );
        }

        if (_baseFee + fee > 0) {
            emit FeeTaken(
                msg.sender,
                _accountTo,
                _token,
                _amount,
                fee,
                _baseFee,
                fee + _baseFee,
                _withdrawRequestId
            );
        }

        return withdrawAmount;
    }

    /**
     * @notice starts save funds lockup timer change.
     * @param _time lock up time duration
     */

    function startSaveFundsLockUpTimerChange(uint256 _time)
        external
        override
        onlyOwner
        validAmount(_time)
    {
        newSaveFundsLockUpTime = _time;
        durationToChangeTimer = saveFundsLockupTime + block.timestamp;

        emit saveFundsLockUpTimerStarted(
            msg.sender,
            _time,
            durationToChangeTimer
        );
    }

    /**
     * @notice set save funds lockup time.
     */

    function setSaveFundsLockUpTime() external override onlyOwner {
        require(
            durationToChangeTimer <= block.timestamp &&
                durationToChangeTimer != 0,
            "action not yet possible"
        );

        saveFundsLockupTime = newSaveFundsLockUpTime;
        durationToChangeTimer = 0;

        emit saveFundsLockUpTimeSet(
            msg.sender,
            saveFundsLockupTime,
            durationToChangeTimer
        );
    }

    /**
     * @notice Starts save funds transfer
     * @param _token Token's balance the owner wants to withdraw
     * @param _to Receiver address
     */

    function startSaveFunds(address _token, address _to)
        external
        override
        onlyOwner
        whenPaused
        validAddress(_token)
        validAddress(_to)
    {
        tokenAddressToSaveFunds = _token;
        userAddressToSaveFundsTo = _to;

        saveFundsTimer = block.timestamp + saveFundsLockupTime;

        emit saveFundsStarted(msg.sender, _token, _to);
    }

    /**
     * @notice Will be called once the contract is paused and token's available liquidity will be manually moved
     */

    function executeSaveFunds() external override onlyOwner whenPaused {
        require(
            saveFundsTimer <= block.timestamp && saveFundsTimer != 0,
            "action not yet possible"
        );

        uint256 balance = IERC20Upgradeable(tokenAddressToSaveFunds).balanceOf(
            vaultConfig.getComposableHolding()
        );
        if (balance == 0) {
            saveFundsTimer = 0;
            return;
        } else {
            IComposableHolding(vaultConfig.getComposableHolding()).transfer(
                tokenAddressToSaveFunds,
                userAddressToSaveFundsTo,
                balance
            );
            saveFundsTimer = 0;
        }
        emit LiquidityMoved(msg.sender, userAddressToSaveFundsTo, balance);
    }

    /**
     * @notice Used to transfer randomly sent tokens to this contract to the composable holding
     * @param _token Token's address
     */
    function digestFunds(address _token)
        external
        override
        onlyOwner
        validAddress(_token)
    {
        uint256 balance = IERC20Upgradeable(_token).balanceOf(address(this));
        require(balance > 0, "Nothing to transfer");
        IERC20Upgradeable(_token).safeTransfer(
            vaultConfig.getComposableHolding(),
            balance
        );
        emit FundsDigested(_token, balance);
    }

    /*
    this method is called by the relayer after a successful transfer of tokens between layers
    this is called to unlock the funds to be added in the liquidity of the vault
    */
    function unlockTransferFunds(
        address _token,
        uint256 _amount,
        bytes32 _id
    ) public override whenNotPaused onlyOwnerOrRelayer {
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
            vaultConfig.lockedTransferFunds(_token) - _amount
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
    ) external override onlyOwnerOrRelayer nonReentrant {
        require(hasBeenRefunded[_id] == false, "Already refunded");

        // unlock the funds
        if (hasBeenUnlocked[_id] == false) {
            unlockTransferFunds(_token, _amount, _id);
        }

        hasBeenRefunded[_id] = true;
        lastRefundedID = _id;

        IComposableHolding(vaultConfig.getComposableHolding()).transfer(
            _token,
            _user,
            _amount
        );

        delete deposits[_id];

        emit TransferFundsRefunded(_token, _user, _amount, _id);
    }

    function getRemoteTokenAddress(uint256 _networkID, address _tokenAddress)
        external
        view
        override
        returns (address _tokenAddressRemote)
    {
        _tokenAddressRemote = vaultConfig.remoteTokenAddress(
            _networkID,
            _tokenAddress
        );
    }

    receive() external payable {
        provideEthLiquidity(vaultConfig.maxLimitLiquidityBlocks());
    }

    function _swap(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _tokenIn,
        address _tokenOut,
        uint256 _ammID,
        bytes memory _data
    ) private returns (uint256) {
        address composableHolding = vaultConfig.getComposableHolding();
        IComposableHolding(composableHolding).transfer(
            _tokenIn,
            address(this),
            _amountIn
        );
        address ammAddress = vaultConfig.getAMMAddress(_ammID);
        require(ammAddress != address(0), "AMM not supported");

        IERC20Upgradeable(_tokenIn).safeApprove(ammAddress, _amountIn);

        uint256 amountToSend = IComposableExchange(ammAddress).swap(
            _tokenIn,
            _tokenOut,
            _amountIn,
            _amountOutMin,
            _data
        );
        require(amountToSend >= _amountOutMin, "AMM: Price to low");
        IERC20Upgradeable(_tokenOut).safeTransfer(
            composableHolding,
            amountToSend
        );
        return amountToSend;
    }

    function _updateAvailableTokenAfter(
        address _token,
        uint256 _blocksForActiveLiquidity
    ) private {
        uint256 _availableAfter = availableAfterBlock[msg.sender][_token];
        uint256 _newAvailability = block.number + _blocksForActiveLiquidity;
        if (_availableAfter < _newAvailability) {
            availableAfterBlock[msg.sender][_token] = _newAvailability;
        }
    }

    /// @notice External callable function to pause the contract
    function pause() external override whenNotPaused onlyOwner {
        _pause();
    }

    /// @notice External callable function to unpause the contract
    function unpause() external override whenPaused onlyOwner {
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

    modifier onlyWhitelistedToken(address _tokenAddress) {
        require(
            vaultConfig.getUnderlyingIOUAddress(_tokenAddress) != address(0),
            "token not whitelisted"
        );
        _;
    }

    modifier onlyWhitelistedRemoteTokens(
        uint256 _networkID,
        address _tokenAddress
    ) {
        require(
            vaultConfig.remoteTokenAddress(_networkID, _tokenAddress) !=
                address(0),
            "token not whitelisted in this network"
        );
        _;
    }

    modifier whenNotPausedNetwork(uint256 _networkID) {
        require(paused() == false, "Contract is paused");
        require(pausedNetwork[_networkID] == false, "Network is paused");
        _;
    }

    modifier differentAddresses(
        address _tokenAddress,
        address _tokenAddressReceive
    ) {
        require(_tokenAddress != _tokenAddressReceive, "Same token address");
        _;
    }

    modifier enoughLiquidityInVault(address _tokenAddress, uint256 _amount) {
        require(
            vaultConfig.getCurrentTokenLiquidity(_tokenAddress) >= _amount,
            "Not enough tokens in the vault"
        );
        _;
    }

    modifier notAlreadyWithdrawn(bytes32 _id) {
        require(hasBeenWithdrawn[_id] == false, "Already withdrawn");
        _;
    }

    modifier inTokenTransferLimits(address _token, uint256 _amount) {
        require(
            vaultConfig.inTokenTransferLimits(_token, _amount),
            "Amount out of token transfer limits"
        );
        _;
    }

    modifier onlyOwnerOrRelayer() {
        require(
            _msgSender() == owner() || _msgSender() == relayer,
            "Only owner or relayer"
        );
        _;
    }

    modifier availableToWithdrawLiquidity(address _token) {
        require(
            availableAfterBlock[msg.sender][_token] <= block.number,
            "Can't withdraw token in this block"
        );
        _;
    }
}