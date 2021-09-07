// SPDX-License-Identifier: MIT
// @unsupported: ovm

/**
 * Created on 2021-06-07 08:50
 * @summary: Vault for storing ERC20 tokens that will be transferred by external event-based system to another network. The destination network can be checked on "connectedNetwork"
 * @author: Composable Finance - Pepe Blasco
 */
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "../interfaces/IComposableHolding.sol";
import "../interfaces/IComposableExchange.sol";
import "../interfaces/IReceiptBase.sol";
import "../interfaces/ITokenFactory.sol";

import "../libraries/FeeOperations.sol";

//@title: Composable Finance L2 ERC20 Vault
contract L2Vault is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeMath for uint256;

    uint256 nonce;
    uint256 minFee;
    uint256 maxFee;
    uint256 feeThreshold;
    uint256 transferLockupTime;
    uint256 public minLimitLiquidityBlocks;
    uint256 public maxLimitLiquidityBlocks;
    address public feeAddress;
    string private constant tokenName = "IOU-";

    mapping(uint256 => bool) public pausedNetwork;

    IComposableHolding private composableHolding;
    ITokenFactory private iouTokenFactory;

    /*
    UNISWAP = 2
    SUSHISWAP = 3
    CURVE = 4
    */
    mapping(uint256 => address) private supportedAMMs;

    mapping(bytes32 => bool) public hasBeenWithdrawn;
    mapping(bytes32 => bool) public hasBeenUnlocked;
    mapping(bytes32 => bool) public hasBeenRefunded;

    bytes32 public lastWithdrawID;
    bytes32 public lastUnlockID;
    bytes32 public lastRefundedID;

    mapping(address => uint256) public lastTransfer;
    mapping(uint256 => mapping(address => address)) public remoteTokenAddress; // remoteTokenAddress[networkID][addressHere] = addressThere
    mapping(address => uint256) public lockedTransferFunds;
    /// @dev Store the address of the IOU token receipt
    mapping(address => address) public underlyingIOUAddress;

    event TransferInitiated(
        address indexed account,
        address indexed erc20,
        address remoteTokenAddress,
        uint256 indexed remoteNetworkID,
        uint256 value,
        address remoteDestinationAddress,
        bytes32 uniqueId,
        uint256 transferDelay
    );
    event TokenAdded(
        address indexed erc20,
        address indexed remoteTokenAddress,
        uint256 indexed remoteNetworkID
    );
    event TokenRemoved(
        address indexed erc20,
        address indexed remoteTokenAddress,
        uint256 indexed remoteNetworkID
    );
    event MinFeeChanged(uint256 newMinFee);
    event MaxFeeChanged(uint256 newMaxFee);
    event MinLiquidityBlockChanged(uint256 newMinLimitLiquidityBlocks);
    event MaxLiquidityBlockChanged(uint256 newMaxLimitLiquidityBlocks);
    event ThresholdFeeChanged(uint256 newFeeThreshold);
    event FeeAddressChanged(address feeAddress);
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
    event LockupTimeChanged(
        address indexed _owner,
        uint256 _oldVal,
        uint256 _newVal,
        string valType
    );
    event PauseNetwork(address admin, uint256 networkID);
    event UnpauseNetwork(address admin, uint256 networkID);
    event FeeTaken(
        address indexed _owner,
        address indexed _user,
        address indexed _token,
        uint256 _amount,
        uint256 _fee,
        bytes32 uniqueId
    );

    event TokenReceiptCreated(address underlyingToken);

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

    function initialize(address _feeAddress, address _composableHolding)
        public
        initializer
    {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        nonce = 0;
        // 0.25%
        minFee = 25;
        // 5%
        maxFee = 500;
        // 30% of liquidity
        feeThreshold = 30;
        transferLockupTime = 1 days;
        // 1 day
        minLimitLiquidityBlocks = 1;
        //yet to be decided
        maxLimitLiquidityBlocks = 100;

        feeAddress = _feeAddress;
        composableHolding = IComposableHolding(_composableHolding);
    }

    /// @notice Public function to add address of the AMM used to swap tokens
    /// @param ammID the integer constant for the AMM
    /// @param ammAddress Address of the AMM
    /// @dev AMM should be a wrapper created by us over the AMM implementation
    function addSupportedAMM(uint256 ammID, address ammAddress)
        public
        onlyOwner
        validAddress(ammAddress)
    {
        supportedAMMs[ammID] = ammAddress;
    }

    /// @notice Public function to remove address of the AMM
    /// @param ammID the integer constant for the AMM
    function removeSupportedAMM(uint256 ammID) public onlyOwner {
        delete supportedAMMs[ammID];
    }

    /// @notice External function used to set the IOU Token Factory Address
    /// @dev Address of the factory need to be set after the initialization in order to use the vault
    /// @param iouTokenFactoryAddress Address of the already deployed IOU Token Factory
    function setIOUTokenFactoryAddress(address iouTokenFactoryAddress)
        external
        onlyOwner
        validAddress(iouTokenFactoryAddress)
    {
        iouTokenFactory = ITokenFactory(iouTokenFactoryAddress);
    }

    function _generateId() private returns (bytes32) {
        return
            keccak256(abi.encodePacked(block.number, address(this), nonce++));
    }

    // @notice: Adds a supported token to the contract, allowing for anyone to deposit their tokens.
    // @param tokenAddress  SC address of the ERC20 token to add to supported tokens

    function addSupportedToken(
        address tokenAddress,
        address tokenAddressRemote,
        uint256 remoteNetworkID
    ) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        require(tokenAddressRemote != address(0), "Invalid token address");
        require(remoteNetworkID > 0, "Invalid network ID");

        _deployIOU(tokenAddress);

        remoteTokenAddress[remoteNetworkID][tokenAddress] = tokenAddressRemote;

        emit TokenAdded(tokenAddress, tokenAddressRemote, remoteNetworkID);
    }

    // @notice: removes supported token from the contract, avoiding new deposits and withdrawals.
    // @param tokenAddress  SC address of the ERC20 token to remove from supported tokens

    function removeSupportedToken(address tokenAddress, uint256 remoteNetworkID)
        external
        onlyOwner
        onlySupportedRemoteTokens(remoteNetworkID, tokenAddress)
    {
        emit TokenRemoved(
            tokenAddress,
            remoteTokenAddress[remoteNetworkID][tokenAddress],
            remoteNetworkID
        );
        delete remoteTokenAddress[remoteNetworkID][tokenAddress];
        delete underlyingIOUAddress[tokenAddress];
    }

    function setTransferLockupTime(uint256 lockupTime) external onlyOwner {
        emit LockupTimeChanged(
            msg.sender,
            transferLockupTime,
            lockupTime,
            "Transfer"
        );
        transferLockupTime = lockupTime;
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

    // @notice: Updates the minimum fee
    // @param newMinFee
    function setMinFee(uint256 newMinFee) external onlyOwner {
        require(
            newMinFee < FeeOperations.feeFactor,
            "Min fee cannot be more than fee factor"
        );
        require(newMinFee < maxFee, "Min fee cannot be more than max fee");

        minFee = newMinFee;
        emit MinFeeChanged(newMinFee);
    }

    // @notice: Updates the maximum fee
    // @param newMaxFee
    function setMaxFee(uint256 newMaxFee) external onlyOwner {
        require(
            newMaxFee < FeeOperations.feeFactor,
            "Max fee cannot be more than fee factor"
        );
        require(newMaxFee > minFee, "Max fee cannot be less than min fee");

        maxFee = newMaxFee;
        emit MaxFeeChanged(newMaxFee);
    }

    // @notice: Updates the minimum limit liquidity block
    // @param newMinLimitLiquidityBlocks
    function setMinLimitLiquidityBlocks(uint256 newMinLimitLiquidityBlocks)
        external
        onlyOwner
    {
        require(
            newMinLimitLiquidityBlocks < maxLimitLiquidityBlocks,
            "Min liquidity block cannot be more than max liquidity block"
        );

        minLimitLiquidityBlocks = newMinLimitLiquidityBlocks;
        emit MinLiquidityBlockChanged(newMinLimitLiquidityBlocks);
    }

    // @notice: Updates the maximum limit liquidity block
    // @param newMaxLimitLiquidityBlocks
    function setMaxLimitLiquidityBlocks(uint256 newMaxLimitLiquidityBlocks)
        external
        onlyOwner
    {
        require(
            newMaxLimitLiquidityBlocks > minLimitLiquidityBlocks,
            "Max liquidity block cannot be lower than min liquidity block"
        );

        maxLimitLiquidityBlocks = newMaxLimitLiquidityBlocks;
        emit MaxLiquidityBlockChanged(newMaxLimitLiquidityBlocks);
    }

    // @notice: Updates the fee threshold
    // @param newThresholdFee
    function setThresholdFee(uint256 newThresholdFee) external onlyOwner {
        require(
            newThresholdFee < 100,
            "Threshold fee cannot be more than threshold factor"
        );

        feeThreshold = newThresholdFee;
        emit ThresholdFeeChanged(newThresholdFee);
    }

    // @notice: Updates the account where to send deposit fees
    // @param newFeeAddress
    function setFeeAddress(address newFeeAddress) external onlyOwner {
        require(newFeeAddress != address(0), "Invalid fee address");

        feeAddress = newFeeAddress;
        emit FeeAddressChanged(feeAddress);
    }

    // @notice: checks for the current balance of this contract's address on the ERC20 contract
    // @param tokenAddress  SC address of the ERC20 token to get liquidity from
    function getCurrentTokenLiquidity(address tokenAddress)
        public
        view
        returns (uint256)
    {
        require(
            address(composableHolding) != address(0),
            "Composable Holding address not set"
        );
        // remove the locked transfer funds from the balance of the vault
        return
            IERC20(tokenAddress).balanceOf(address(composableHolding)).sub(
                lockedTransferFunds[tokenAddress]
            );
    }

    // @notice transfer ERC20 token to another l2 vault
    // @param amount amount of tokens to deposit
    // @param tokenAddress  SC address of the ERC20 token to deposit
    // @param transferDelay delay in seconds for the relayer to execute the transaction
    function transferERC20ToLayer(
        uint256 amount,
        address tokenAddress,
        address remoteDestinationAddress,
        uint256 remoteNetworkID,
        uint256 transferDelay
    )
        external
        validAmount(amount)
        onlySupportedRemoteTokens(remoteNetworkID, tokenAddress)
        nonReentrant
        whenNotPausedNetwork(remoteNetworkID)
    {
        require(
            lastTransfer[msg.sender].add(transferLockupTime) < block.timestamp,
            "Transfer not yet possible"
        );
        SafeERC20.safeTransferFrom(
            IERC20(tokenAddress),
            msg.sender,
            address(composableHolding),
            amount
        );

        uint256 newLockedAmount = lockedTransferFunds[tokenAddress].add(amount);
        lockedTransferFunds[tokenAddress] = newLockedAmount;

        lastTransfer[msg.sender] = block.timestamp;
        bytes32 id = _generateId();
        emit TransferInitiated(
            msg.sender,
            tokenAddress,
            remoteTokenAddress[remoteNetworkID][tokenAddress],
            remoteNetworkID,
            amount,
            remoteDestinationAddress,
            id,
            transferDelay
        );
    }

    function provideLiquidity(
        uint256 amount,
        address tokenAddress,
        uint256 blocksForActiveLiquidity
    )
        external
        validAddress(tokenAddress)
        validAmount(amount)
        onlySupportedToken(tokenAddress)
        nonReentrant
        whenNotPaused
    {
        require(
            blocksForActiveLiquidity >= minLimitLiquidityBlocks &&
                blocksForActiveLiquidity <= maxLimitLiquidityBlocks,
            "not within block approve range"
        );
        SafeERC20.safeTransferFrom(
            IERC20(tokenAddress),
            msg.sender,
            address(composableHolding),
            amount
        );
        IReceiptBase(underlyingIOUAddress[tokenAddress]).mint(
            msg.sender,
            amount
        );
        emit DepositLiquidity(
            tokenAddress,
            msg.sender,
            amount,
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

        IReceiptBase(underlyingIOUAddress[_tokenAddress]).mint(_user, _amount);

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
        onlySupportedToken(tokenOut)
        onlySupportedToken(tokenIn)
        differentAddresses(tokenIn, tokenOut)
        isAMMSupported(ammID)
    {
        _burnIOUTokens(tokenIn, msg.sender, amountIn);
        composableHolding.transfer(tokenIn, address(this), amountIn);
        SafeERC20.safeApprove(IERC20(tokenIn), supportedAMMs[ammID], amountIn);
        uint256 amountToSend = IComposableExchange(supportedAMMs[ammID]).swap(
            tokenIn,
            tokenOut,
            amountIn,
            amountOutMin,
            data
        );
        SafeERC20.safeTransfer(IERC20(tokenOut), msg.sender, amountToSend);
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
        onlySupportedRemoteTokens(_networkID, tokenAddress)
    {
        _burnIOUTokens(tokenAddress, msg.sender, amount);

        emit WithdrawOnRemoteNetworkStarted(
            msg.sender,
            tokenAddress,
            remoteTokenAddress[_networkID][tokenAddress],
            _networkID,
            amount,
            remoteDestinationAddress,
            _generateId()
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
        onlySupportedToken(tokenOut)
        onlySupportedToken(tokenIn)
        onlySupportedRemoteTokens(networkID, tokenOut)
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
            remoteTokenAddress[networkID][tokenOut],
            networkID,
            amountIn,
            amountOutMin,
            remoteDestinationAddress,
            remoteAmmId,
            _generateId()
        );
    }

    function _burnIOUTokens(
        address tokenAddress,
        address provider,
        uint256 amount
    ) internal {
        IReceiptBase t = IReceiptBase(underlyingIOUAddress[tokenAddress]);
        require(t.balanceOf(provider) >= amount, "IOU Token balance to low");
        t.burn(provider, amount);
    }

    function calculateFeePercentage(address tokenAddress, uint256 amount)
        public
        view
        returns (uint256)
    {
        uint256 tokenLiquidity = getCurrentTokenLiquidity(tokenAddress);

        if (tokenLiquidity == 0) {
            return maxFee;
        }

        if ((amount.mul(100)).div(tokenLiquidity) > feeThreshold) {
            // Flat fee since it's above threshold
            return maxFee;
        }

        uint256 maxTransfer = tokenLiquidity.mul(feeThreshold).div(100);
        uint256 percentTransfer = amount.mul(100).div(maxTransfer);

        return
            percentTransfer.mul(maxFee.sub(minFee)).add(minFee.mul(100)).div(
                100
            );
    }

    // @notice: method called by the relayer to release funds
    // @param accountTo eth address to send the withdrawal tokens
    function withdrawTo(
        address accountTo,
        uint256 amount,
        address tokenAddress,
        bytes32 id
    )
        external
        onlySupportedToken(tokenAddress)
        enoughLiquidityInVault(tokenAddress, amount)
        nonReentrant
        onlyOwner
        whenNotPaused
        notAlreadyWithdrawn(id)
    {
        _withdraw(accountTo, amount, tokenAddress, address(0), id, 0, 0, "");
    }

    // @notice: method called by the relayer to release funds in different token
    // @param accountTo eth address to send the withdrawal tokens
    // @param amount amount of token in
    // @param tokenIn address of the token in
    // @param tokenOut address of the token out
    // @param id withdrawal id
    // @param amountOutMin minimum amount out user want
    // @param data additional data required for each AMM implementation
    function withdrawDifferentTokenTo(
        address accountTo,
        uint256 amount,
        address tokenIn,
        address tokenOut,
        bytes32 id,
        uint256 amountOutMin,
        uint256 ammID,
        bytes calldata data
    )
        external
        onlySupportedToken(tokenIn)
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
        uint256 amountOutMin,
        uint256 ammID,
        bytes memory data
    ) private {
        hasBeenWithdrawn[id] = true;
        lastWithdrawID = id;
        uint256 withdrawAmount = _takeFees(tokenIn, amount, accountTo, id);

        if (tokenOut == address(0)) {
            composableHolding.transfer(tokenIn, accountTo, withdrawAmount);
        } else {
            require(supportedAMMs[ammID] != address(0), "AMM not supported");
            composableHolding.transfer(tokenIn, address(this), withdrawAmount);
            SafeERC20.safeApprove(
                IERC20(tokenIn),
                supportedAMMs[ammID],
                withdrawAmount
            );
            uint256 amountToSend = IComposableExchange(supportedAMMs[ammID])
                .swap(tokenIn, tokenOut, withdrawAmount, amountOutMin, data);
            require(amountToSend >= amountOutMin, "AMM: Price to low");
            SafeERC20.safeTransfer(IERC20(tokenOut), accountTo, amountToSend);
        }

        emit WithdrawalCompleted(accountTo, amount, withdrawAmount, tokenIn, id);
    }

    function _takeFees(
        address token,
        uint256 amount,
        address accountTo,
        bytes32 withdrawRequestId
    ) private returns (uint256) {
        uint256 fee = calculateFeePercentage(token, amount);
        uint256 feeAbsolute = FeeOperations.getFeeAbsolute(amount, fee);
        uint256 withdrawAmount = amount.sub(feeAbsolute);

        if (feeAbsolute > 0) {
            composableHolding.transfer(token, feeAddress, feeAbsolute);
            emit FeeTaken(
                msg.sender,
                accountTo,
                token,
                amount,
                feeAbsolute,
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
        uint256 balance = IERC20(_token).balanceOf(address(composableHolding));
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
        uint256 tokenLiquidity = getCurrentTokenLiquidity(_token);
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
            lockedTransferFunds[_token] >= _amount,
            "More amount than available"
        );

        hasBeenUnlocked[_id] = true;
        lastUnlockID = _id;

        // update the lockedTransferFunds for the token
        uint256 newInTransferFunds = lockedTransferFunds[_token].sub(_amount);
        lockedTransferFunds[_token] = newInTransferFunds;

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

        emit TransferFundsRefunded(_token, _user, _amount, _id);
    }

    /// @dev Internal function called when deploy a receipt IOU token based on already deployed ERC20 token
    function _deployIOU(address underlyingToken) private returns (address) {
        require(
            address(iouTokenFactory) != address(0),
            "IOU token factory not initialized"
        );

        address newIou = iouTokenFactory.createIOU(
            underlyingToken,
            tokenName
        );

        underlyingIOUAddress[underlyingToken] = newIou;

        emit TokenReceiptCreated(underlyingToken);
        return newIou;
    }

    function getRemoteTokenAddress(uint256 _networkID, address _tokenAddress)
        external
        view
        returns (address tokenAddressRemote)
    {
        tokenAddressRemote = remoteTokenAddress[_networkID][_tokenAddress];
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

    modifier onlySupportedToken(address tokenAddress) {
        require(
            underlyingIOUAddress[tokenAddress] != address(0),
            "Unsupported token"
        );
        _;
    }

    modifier onlySupportedRemoteTokens(
        uint256 networkID,
        address tokenAddress
    ) {
        require(
            remoteTokenAddress[networkID][tokenAddress] != address(0),
            "Unsupported token in this network"
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
        require(supportedAMMs[ammID] != address(0), "AMM not supported");
        _;
    }

    modifier enoughLiquidityInVault(address tokenAddress, uint256 amount) {
        require(
            getCurrentTokenLiquidity(tokenAddress) >= amount,
            "Not enough tokens in the vault"
        );
        _;
    }

    modifier notAlreadyWithdrawn(bytes32 id) {
        require(hasBeenWithdrawn[id] == false, "Already withdrawn");
        _;
    }
}