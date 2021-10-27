// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IL2VaultConfig.sol";
import "../interfaces/IComposableHolding.sol";
import "../interfaces/ITokenFactory.sol";
import "../libraries/FeeOperations.sol";
import "./VaultConfigBase.sol";

contract L2VaultConfig is VaultConfigBase, IL2VaultConfig {
    using SafeMath for uint256;

    uint256 nonce;
    uint256 public override minFee;
    uint256 public override maxFee;
    uint256 public override feeThreshold;
    uint256 public override transferLockupTime;
    uint256 public override minLimitLiquidityBlocks;
    uint256 public override maxLimitLiquidityBlocks;
    uint256 public constant override tokenRatio = 1000;
    address public override feeAddress;
    address public override wethAddress;
    string internal constant tokenName = "IOU-";

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
        address underlyingReceiptAddress;
    }

    event MinFeeChanged(uint256 newMinFee);
    event MaxFeeChanged(uint256 newMaxFee);
    event MinLiquidityBlockChanged(uint256 newMinLimitLiquidityBlocks);
    event MaxLiquidityBlockChanged(uint256 newMaxLimitLiquidityBlocks);
    event ThresholdFeeChanged(uint256 newFeeThreshold);
    event FeeAddressChanged(address feeAddress);
    event LockupTimeChanged(
        address indexed _owner,
        uint256 _oldVal,
        uint256 _newVal,
        string valType
    );
    event TokenWhitelisted(address indexed erc20, address indexed newIou);
    event TokenWhitelistRemoved(address indexed erc20);
    event RemoteTokenAdded(
        address indexed _erc20,
        address indexed _remoteErc20,
        uint256 indexed _remoteNetworkID,
        uint256 _remoteTokenRatio
    );
    event RemoteTokenRemoved(
        address indexed erc20,
        uint256 indexed remoteNetworkID
    );

    constructor(address _feeAddress, address _composableHolding) {
        require(
            _composableHolding != address(0),
            "Invalid ComposableHolding address"
        );
        require(_feeAddress != address(0), "Invalid fee address");

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

    function getAMMAddress(uint256 ammID)
        external
        view
        override
        returns (address)
    {
        return supportedAMMs[ammID];
    }

    function getUnderlyingReceiptAddress(address token)
        external
        view
        override
        returns (address)
    {
        return whitelistedTokens[token].underlyingReceiptAddress;
    }

    // @notice: checks for the current balance of this contract's address on the ERC20 contract
    // @param tokenAddress  SC address of the ERC20 token to get liquidity from
    function getCurrentTokenLiquidity(address tokenAddress)
        public
        view
        override
        returns (uint256)
    {
        uint256 tokenBalance = getTokenBalance(tokenAddress);
        // remove the locked transfer funds from the balance of the vault
        return tokenBalance.sub(lockedTransferFunds[tokenAddress]);
    }

    function calculateFeePercentage(address tokenAddress, uint256 amount)
        external
        view
        override
        returns (uint256)
    {
        uint256 tokenLiquidity = getTokenBalance(tokenAddress);

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

    /// @notice Public function to add address of the AMM used to swap tokens
    /// @param ammID the integer constant for the AMM
    /// @param ammAddress Address of the AMM
    /// @dev AMM should be a wrapper created by us over the AMM implementation
    function addSupportedAMM(uint256 ammID, address ammAddress)
        public
        override
        onlyOwner
        validAddress(ammAddress)
    {
        supportedAMMs[ammID] = ammAddress;
    }

    /// @notice Public function to remove address of the AMM
    /// @param ammID the integer constant for the AMM
    function removeSupportedAMM(uint256 ammID) public override onlyOwner {
        delete supportedAMMs[ammID];
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
    /// @param tokenAddress  SC address of the ERC20 token to add to whitelisted tokens
    function addWhitelistedToken(
        address tokenAddress,
        uint256 minTransferAmount,
        uint256 maxTransferAmount
    ) external override onlyOwner validAddress(tokenAddress) {
        require(
            maxTransferAmount > minTransferAmount,
            "Invalid token economics"
        );

        require(
            whitelistedTokens[tokenAddress].underlyingReceiptAddress ==
                address(0),
            "Token already whitelisted"
        );

        address newIou = _deployIOU(tokenAddress);
        whitelistedTokens[tokenAddress].minTransferAllowed = minTransferAmount;
        whitelistedTokens[tokenAddress].maxTransferAllowed = maxTransferAmount;

        emit TokenWhitelisted(tokenAddress, newIou);
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
    {
        require(
            whitelistedTokens[_tokenAddress].underlyingReceiptAddress !=
                address(0),
            "Token not whitelisted"
        );
        require(_remoteNetworkID > 0, "Invalid network ID");

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
    ) external override onlyOwner validAddress(_tokenAddress) {
        require(_remoteNetworkID > 0, "Invalid network ID");
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
            whitelistedTokens[_tokenAddress].underlyingReceiptAddress !=
                address(0),
            "Token not whitelisted"
        );
        emit TokenWhitelistRemoved(_tokenAddress);
        delete whitelistedTokens[_tokenAddress];
    }

    function setTransferLockupTime(uint256 lockupTime)
        external
        override
        onlyOwner
    {
        emit LockupTimeChanged(
            msg.sender,
            transferLockupTime,
            lockupTime,
            "Transfer"
        );
        transferLockupTime = lockupTime;
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
    // @param newMinFee
    function setMinFee(uint256 newMinFee) external override onlyOwner {
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
    function setMaxFee(uint256 newMaxFee) external override onlyOwner {
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
        override
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
        override
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
    function setThresholdFee(uint256 newThresholdFee)
        external
        override
        onlyOwner
    {
        require(
            newThresholdFee < 100,
            "Threshold fee cannot be more than threshold factor"
        );

        feeThreshold = newThresholdFee;
        emit ThresholdFeeChanged(newThresholdFee);
    }

    // @notice: Updates the account where to send deposit fees
    // @param newFeeAddress
    function setFeeAddress(address newFeeAddress) external override onlyOwner {
        require(newFeeAddress != address(0), "Invalid fee address");

        feeAddress = newFeeAddress;
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
    function _deployIOU(address underlyingToken) private returns (address) {
        require(
            address(receiptTokenFactory) != address(0),
            "IOU token factory not initialized"
        );
        require(address(vault) != address(0), "Vault not initialized");

        address newIou = receiptTokenFactory.createIOU(
            underlyingToken,
            tokenName,
            vault
        );

        whitelistedTokens[underlyingToken].underlyingReceiptAddress = newIou;

        emit TokenReceiptCreated(underlyingToken);
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
        uint256 networkID,
        address tokenAddress
    ) {
        require(
            whitelistedTokens[tokenAddress].underlyingReceiptAddress !=
                address(0),
            "Token not whitelisted"
        );
        require(
            remoteTokenAddress[networkID][tokenAddress] != address(0),
            "token not whitelisted in this network"
        );
        _;
    }
}