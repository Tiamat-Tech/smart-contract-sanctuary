// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IMosaicVaultConfig.sol";
import "../interfaces/IComposableHolding.sol";
import "../interfaces/ITokenFactory.sol";
import "../libraries/FeeOperations.sol";
import "./VaultConfigBase.sol";

contract MosaicVaultConfig is VaultConfigBase, IMosaicVaultConfig {
    uint256 public constant override tokenRatio = 1000;
    string internal constant tokenName = "IOU-";

    uint256 nonce;
    uint256 public override minFee;
    uint256 public override maxFee;
    uint256 public override feeThreshold;
    uint256 public override transferLockupTime;
    uint256 public override minLimitLiquidityBlocks;
    uint256 public override maxLimitLiquidityBlocks;

    address public override feeAddress;
    address public override wethAddress;

    // @dev remoteTokenAddress[networkID][addressHere] = addressThere
    mapping(uint256 => mapping(address => address))
        public
        override remoteTokenAddress;
    mapping(uint256 => mapping(address => uint256))
        public
        override remoteTokenRatio;
    mapping(address => uint256) public override lockedTransferFunds;

    /*
    UNISWAP = 2
    SUSHISWAP = 3
    CURVE = 4
    */
    mapping(uint256 => address) private supportedAMMs;

    /// @notice Public function to query the whitelisted tokens list
    /// @dev token address => WhitelistedToken struct
    mapping(address => WhitelistedToken) public whitelistedTokens;

    struct WhitelistedToken {
        uint256 minTransferAllowed;
        uint256 maxTransferAllowed;
        address underlyingIOUAddress;
    }

    function initialize(address _feeAddress, address _composableHolding)
        public
        initializer
    {
        require(
            _composableHolding != address(0),
            "Invalid ComposableHolding address"
        );
        require(_feeAddress != address(0), "Invalid fee address");

        __Ownable_init();

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

    function setWethAddress(address _weth)
        external
        override
        onlyOwner
        validAddress(_weth)
    {
        wethAddress = _weth;
    }

    function getAMMAddress(uint256 _ammID)
        external
        view
        override
        returns (address)
    {
        return supportedAMMs[_ammID];
    }

    function getUnderlyingIOUAddress(address _token)
        external
        view
        override
        returns (address)
    {
        return whitelistedTokens[_token].underlyingIOUAddress;
    }

    // @notice: checks for the current balance of this contract's address on the ERC20 contract
    // @param tokenAddress  SC address of the ERC20 token to get liquidity from
    function getCurrentTokenLiquidity(address _tokenAddress)
        public
        view
        override
        returns (uint256)
    {
        uint256 tokenBalance = getTokenBalance(_tokenAddress);
        // remove the locked transfer funds from the balance of the vault
        return tokenBalance - lockedTransferFunds[_tokenAddress];
    }

    function calculateFeePercentage(address _tokenAddress, uint256 _amount)
        external
        view
        override
        returns (uint256)
    {
        uint256 tokenLiquidity = getTokenBalance(_tokenAddress);

        if (tokenLiquidity == 0) {
            return maxFee;
        }

        if ((_amount * 100) / tokenLiquidity > feeThreshold) {
            // Flat fee since it's above threshold
            return maxFee;
        }

        uint256 maxTransfer = (tokenLiquidity * feeThreshold) / 100;
        uint256 percentTransfer = (_amount * 100) / maxTransfer;

        return percentTransfer * (maxFee - minFee) + (minFee * 100) / 100;
    }

    /// @notice Public function to add address of the AMM used to swap tokens
    /// @param _ammID the integer constant for the AMM
    /// @param _ammAddress Address of the AMM
    /// @dev AMM should be a wrapper created by us over the AMM implementation
    function addSupportedAMM(uint256 _ammID, address _ammAddress)
        public
        override
        onlyOwner
        validAddress(_ammAddress)
    {
        supportedAMMs[_ammID] = _ammAddress;
    }

    /// @notice Public function to remove address of the AMM
    /// @param _ammID the integer constant for the AMM
    function removeSupportedAMM(uint256 _ammID) public override onlyOwner {
        delete supportedAMMs[_ammID];
    }

    function changeRemoteTokenRatio(
        address _tokenAddress,
        uint256 _remoteNetworkID,
        uint256 _remoteTokenRatio
    )
        external
        override
        onlyOwner
        validAmount(remoteTokenRatio[_remoteNetworkID][_tokenAddress])
    {
        remoteTokenRatio[_remoteNetworkID][_tokenAddress] = _remoteTokenRatio;
    }

    // @notice: Adds a whitelisted token to the contract, allowing for anyone to deposit their tokens.
    /// @param _tokenAddress  SC address of the ERC20 token to add to whitelisted tokens
    function addWhitelistedToken(
        address _tokenAddress,
        uint256 _minTransferAmount,
        uint256 _maxTransferAmount
    ) external override onlyOwner validAddress(_tokenAddress) {
        require(
            _maxTransferAmount > _minTransferAmount,
            "Invalid token economics"
        );

        require(
            whitelistedTokens[_tokenAddress].underlyingIOUAddress == address(0),
            "Token already whitelisted"
        );

        address newIou = _deployIOU(_tokenAddress);
        whitelistedTokens[_tokenAddress]
            .minTransferAllowed = _minTransferAmount;
        whitelistedTokens[_tokenAddress]
            .maxTransferAllowed = _maxTransferAmount;

        emit TokenWhitelisted(_tokenAddress, newIou);
    }

    function addTokenInNetwork(
        address _tokenAddress,
        address _tokenAddressRemote,
        uint256 _remoteNetworkID,
        uint256 _remoteTokenRatio
    )
        external
        override
        onlyOwner
        validAddress(_tokenAddress)
        validAddress(_tokenAddressRemote)
        notZero(_remoteNetworkID)
    {
        require(
            whitelistedTokens[_tokenAddress].underlyingIOUAddress != address(0),
            "Token not whitelisted"
        );

        remoteTokenAddress[_remoteNetworkID][
            _tokenAddress
        ] = _tokenAddressRemote;
        remoteTokenRatio[_remoteNetworkID][_tokenAddress] = _remoteTokenRatio;

        emit RemoteTokenAdded(
            _tokenAddress,
            _tokenAddressRemote,
            _remoteNetworkID,
            _remoteTokenRatio
        );
    }

    function removeTokenInNetwork(
        address _tokenAddress,
        uint256 _remoteNetworkID
    )
        external
        override
        onlyOwner
        notZero(_remoteNetworkID)
        validAddress(_tokenAddress)
    {
        require(
            remoteTokenAddress[_remoteNetworkID][_tokenAddress] != address(0),
            "Token not whitelisted in that network"
        );

        delete remoteTokenAddress[_remoteNetworkID][_tokenAddress];
        delete remoteTokenRatio[_remoteNetworkID][_tokenAddress];

        emit RemoteTokenRemoved(_tokenAddress, _remoteNetworkID);
    }

    // @notice: removes whitelisted token from the contract, avoiding new deposits and withdrawals.
    // @param tokenAddress  SC address of the ERC20 token to remove from whitelisted tokens
    function removeWhitelistedToken(address _tokenAddress)
        external
        override
        onlyOwner
    {
        require(
            whitelistedTokens[_tokenAddress].underlyingIOUAddress != address(0),
            "Token not whitelisted"
        );
        emit TokenWhitelistRemoved(_tokenAddress);
        delete whitelistedTokens[_tokenAddress];
    }

    function setTransferLockupTime(uint256 _lockupTime)
        external
        override
        onlyOwner
    {
        emit LockupTimeChanged(
            msg.sender,
            transferLockupTime,
            _lockupTime,
            "Transfer"
        );
        transferLockupTime = _lockupTime;
    }

    function setLockedTransferFunds(address _token, uint256 _amount)
        external
        override
        validAddress(_token)
        onlyOwnerOrVault(msg.sender)
    {
        lockedTransferFunds[_token] = _amount;
    }

    // @notice: Updates the minimum fee
    /// @param _newMinFee new minimum fee value
    function setMinFee(uint256 _newMinFee) external override onlyOwner {
        require(
            _newMinFee < FeeOperations.feeFactor,
            "Min fee cannot be more than fee factor"
        );
        require(_newMinFee < maxFee, "Min fee cannot be more than max fee");

        minFee = _newMinFee;
        emit MinFeeChanged(_newMinFee);
    }

    // @notice: Updates the maximum fee
    /// @param _newMaxFee new maximum fee value
    function setMaxFee(uint256 _newMaxFee) external override onlyOwner {
        require(
            _newMaxFee < FeeOperations.feeFactor,
            "Max fee cannot be more than fee factor"
        );
        require(_newMaxFee > minFee, "Max fee cannot be less than min fee");

        maxFee = _newMaxFee;
        emit MaxFeeChanged(_newMaxFee);
    }

    // @notice: Updates the minimum limit liquidity block
    /// @param _newMinLimitLiquidityBlocks new minimum limit liquidity block value
    function setMinLimitLiquidityBlocks(uint256 _newMinLimitLiquidityBlocks)
        external
        override
        onlyOwner
    {
        require(
            _newMinLimitLiquidityBlocks < maxLimitLiquidityBlocks,
            "Min liquidity block cannot be more than max liquidity block"
        );

        minLimitLiquidityBlocks = _newMinLimitLiquidityBlocks;
        emit MinLiquidityBlockChanged(_newMinLimitLiquidityBlocks);
    }

    // @notice: Updates the maximum limit liquidity block
    /// @param _newMaxLimitLiquidityBlocks new maximum limit liquidity block value
    function setMaxLimitLiquidityBlocks(uint256 _newMaxLimitLiquidityBlocks)
        external
        override
        onlyOwner
    {
        require(
            _newMaxLimitLiquidityBlocks > minLimitLiquidityBlocks,
            "Max liquidity block cannot be lower than min liquidity block"
        );

        maxLimitLiquidityBlocks = _newMaxLimitLiquidityBlocks;
        emit MaxLiquidityBlockChanged(_newMaxLimitLiquidityBlocks);
    }

    // @notice: Updates the fee threshold
    /// @param _newThresholdFee new fee threshold value
    function setThresholdFee(uint256 _newThresholdFee)
        external
        override
        onlyOwner
    {
        require(
            _newThresholdFee < 100,
            "Threshold fee cannot be more than threshold factor"
        );

        feeThreshold = _newThresholdFee;
        emit ThresholdFeeChanged(_newThresholdFee);
    }

    // @notice: Updates the account where to send deposit fees
    /// @param _newFeeAddress new fee address
    function setFeeAddress(address _newFeeAddress) external override onlyOwner {
        require(_newFeeAddress != address(0), "Invalid fee address");

        feeAddress = _newFeeAddress;
        emit FeeAddressChanged(feeAddress);
    }

    function generateId()
        external
        override
        onlyVault(msg.sender)
        returns (bytes32)
    {
        nonce = nonce + 1;
        return keccak256(abi.encodePacked(block.number, vault, nonce));
    }

    /// @dev Internal function called when deploy a receipt IOU token based on already deployed ERC20 token
    function _deployIOU(address _underlyingToken) private returns (address) {
        require(
            address(tokenFactory) != address(0),
            "IOU token factory not initialized"
        );
        require(address(vault) != address(0), "Vault not initialized");

        address newIou = tokenFactory.createIOU(
            _underlyingToken,
            tokenName,
            vault
        );

        whitelistedTokens[_underlyingToken].underlyingIOUAddress = newIou;

        emit TokenCreated(_underlyingToken);
        return newIou;
    }

    function inTokenTransferLimits(address _token, uint256 _amount)
        external
        view
        override
        returns (bool)
    {
        return (whitelistedTokens[_token].minTransferAllowed <= _amount &&
            whitelistedTokens[_token].maxTransferAllowed >= _amount);
    }

    modifier onlyOwnerOrVault(address _addr) {
        require(
            _addr == owner() || _addr == vault,
            "Only vault or owner can call this"
        );
        _;
    }

    modifier onlyVault(address _addr) {
        require(_addr == vault, "Only vault can call this");
        _;
    }

    modifier onlyWhitelistedRemoteTokens(
        uint256 _networkID,
        address _tokenAddress
    ) {
        require(
            whitelistedTokens[_tokenAddress].underlyingIOUAddress != address(0),
            "Token not whitelisted"
        );
        require(
            remoteTokenAddress[_networkID][_tokenAddress] != address(0),
            "token not whitelisted in this network"
        );
        _;
    }

    modifier notZero(uint256 _value) {
        require(_value > 0, "Zero value not allowed");
        _;
    }
}