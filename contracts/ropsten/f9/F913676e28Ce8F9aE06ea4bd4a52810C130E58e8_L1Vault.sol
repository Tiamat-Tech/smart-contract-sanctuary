// SPDX-License-Identifier: MIT
// @unsupported: ovm
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "../interfaces/IVaultBase.sol";
import "../interfaces/IComposableHolding.sol";
import "../interfaces/ITokenFactory.sol";
import "../interfaces/IReceiptBase.sol";
import "../interfaces/IBridgeAggregator.sol";

/// @title L1Vault
contract L1Vault is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeMath for uint256;

    string private constant tokenName = "R-";

    IComposableHolding private composableHolding;

    ITokenFactory private receiptTokenFactory;

    IBridgeAggregator private bridgeAggregator;

    /// @notice Public function to query the supported tokens list
    /// @dev token address => bool supported/not supported
    mapping(address => bool) public whitelistedTokens;

    /// @notice Public mapping to store/get the max cap per token
    mapping(address => uint256) public maxAssetCap;

    // @notice Public mapping to keep track for the withdraw paused / asset
    mapping(address => bool) public allowToWithdraw;

    /// @dev Store the address of the Receipt token receipt
    mapping(address => address) public underlyingReceiptAddress;

    /// @notice event emitted when a token is moved to another account
    /// @param token address of the token
    /// @param destination address of the receiver
    /// @param amount token amount send
    event FundsMoved(
        address indexed token,
        address indexed destination,
        uint256 amount
    );    

    /// @notice event emitted when a token is added to the whitelist
    /// @param token address of the token
    /// @param maxCap amount of the max cap of the token
    event TokenAddedToWhitelist(
        address indexed token,
        uint256 maxCap
    );

    /// @notice event emitted when a token is removed from the whitelist
    /// @param token address of the token
    event TokenRemovedFromWhitelist(
        address indexed token
    );

    /// @notice event emitted when a token max cap is modified
    /// @param token address of the token
    /// @param newMaxCap amount of the max cap of the token
    event TokenMaxCapEdited(
        address indexed token,
        uint256 newMaxCap
    );

    /// @notice event emitted when user make a deposit
    /// @param sender address of the person who made the token deposit
    /// @param token address of the token
    /// @param amount amount of token deposited on this action
    /// @param totalAmount total amount of token deposited
    /// @param timestamp block.timestamp timestamp of the deposit
    event ProvideLiquidity(
        address indexed sender,
        address indexed token,
        uint256 amount,
        uint256 indexed totalAmount,
        uint256 timestamp
    );

    /// @notice event emitted when user withdraw token from the contract
    /// @param sender address of the person who withdraw his token
    /// @param token address of the token
    /// @param amount amount of token withdrawn
    /// @param totalAmount total amount of token remained deposited
    /// @param timestamp block.timestamp timestamp of the withdrawal
    event WithdrawLiquidity(
        address indexed sender,
        address indexed token,
        uint256 amount,
        uint256 indexed totalAmount,
        uint256 timestamp
    );

    event TokenReceiptCreated(address underlyingToken);

    function initialize(address _composableHolding) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        composableHolding = IComposableHolding(_composableHolding);
    }

    /// @notice External function used by owner to set the bridge aggregator address
    /// @param _bridgeAggregator Address of the bridge aggregator
    function setBridgeAggregator(address _bridgeAggregator)
        external
        onlyOwner
        validAddress(_bridgeAggregator)
    {
        bridgeAggregator = IBridgeAggregator(_bridgeAggregator);
    }

    /// @notice External function used to set the Receipt Token Factory Address
    /// @dev Address of the factory need to be set after the initialization in order to use the vault
    /// @param receiptTokenFactoryAddress Address of the already deployed Receipt Token Factory
    function setReceiptTokenFactoryAddress(address receiptTokenFactoryAddress)
        external
        onlyOwner
        validAddress(receiptTokenFactoryAddress)
    {
        receiptTokenFactory = ITokenFactory(receiptTokenFactoryAddress);
    }

    /// @notice external function used to add token in the whitelist
    /// @param _token ERC20 token address
    function addWhitelistedToken(address _token, uint256 _maxCap)
        external
        onlyOwner
        validAddress(_token)
        validAmount(_maxCap)
    {
        whitelistedTokens[_token] = true;
        maxAssetCap[_token] = _maxCap;
        _deployReceipt(_token);

        emit TokenAddedToWhitelist(_token, _maxCap);
    }

    function setMaxCapAsset(address _token, uint256 _maxCap)
        external
        onlyOwner
        onlySupportedToken(_token)
        validAmount(_maxCap)
    {
        require(
            getTokenBalance(_token) <= _maxCap,
            "Current token balance is higher"
        );
        maxAssetCap[_token] = _maxCap;

        emit TokenMaxCapEdited(_token, _maxCap);
    }

    /// @notice external function used to remove token from the whitelist
    /// @param _token ERC20 token address
    function removeWhitelistedToken(address _token)
        external
        onlyOwner
        validAddress(_token)
    {
        delete whitelistedTokens[_token];
        delete maxAssetCap[_token];

        emit TokenRemovedFromWhitelist(_token);
    }

    /// @notice callable function used to send asset to another wallet
    /// @param _destination address of the token receiver
    /// @param _token address of the token
    /// @param _amount amount send
    function moveFunds(
        address _destination,
        address _token,
        uint256 _amount
    ) external onlyOwner validAddress(_destination) validAmount(_amount) {
        require(getTokenBalance(_token) >= _amount, "Not enough liquidity");
        composableHolding.transfer(_token, _destination, _amount);
        emit FundsMoved(_token, _destination, _amount);
    }

    /// @notice External function used to move tokens to Layer2 networks
    /// @param destinationNetwork chain id of the destination network
    /// @param destination Address of the receiver on the L2 network
    /// @param token Address of the ERC20 token
    /// @param amount Amount need to be send
    /// @param _data Additional data that different bridge required in order to mint token
    function bridgeTokens(
        uint256 destinationNetwork,
        address destination,
        address token,
        uint256 amount,
        bytes calldata _data
    ) external onlyOwner validAddress(destination) validAmount(amount) {
        composableHolding.approve(address(bridgeAggregator), token, amount);
        bridgeAggregator.bridgeTokens(
            destinationNetwork,
            destination,
            token,
            amount,
            _data
        );
    }

    /// @notice External callable function used to withdraw liquidity from contract
    /// @dev This function withdraw all the liquidity provider staked
    /// @param _token address of the token
    function withdrawLiquidity(address _token) external nonReentrant {
        require(allowToWithdraw[_token], "Withdraw paused for this token");
        uint256 _providerBalance = getReceiptTokenBalance(_token);
        require(_providerBalance > 0, "Provider balance too low");
        require(
            getTokenBalance(_token) >= _providerBalance,
            "Not enough tokens in the vault"
        );
        IReceiptBase(underlyingReceiptAddress[_token]).burn(
            msg.sender,
            _providerBalance
        );

        composableHolding.transfer(_token, msg.sender, _providerBalance);

        emit WithdrawLiquidity(
            msg.sender,
            _token,
            _providerBalance,
            0,
            block.timestamp
        );
    }

    /// @notice External callable function used to add liquidity to contract
    /// @param _token address of the deposited token
    /// @param _amount amount of token deposited
    function provideLiquidity(address _token, uint256 _amount)
        external
        whenNotPaused
        validAmount(_amount)
        onlySupportedToken(_token)
        notOverMaxCap(_token, _amount)
    {
        SafeERC20.safeTransferFrom(
            IERC20(_token),
            msg.sender,
            address(composableHolding),
            _amount
        );
        _provideLiquidity(_token, _amount, msg.sender);
    }

    /// @dev Internal function that contains the deposit logic
    function _provideLiquidity(
        address _token,
        uint256 _amount,
        address _to
    ) internal returns (bool) {
        IReceiptBase(underlyingReceiptAddress[_token]).mint(
            msg.sender,
            _amount
        );

        emit ProvideLiquidity(
            _to,
            _token,
            _amount,
            IReceiptBase(underlyingReceiptAddress[_token]).balanceOf(
                msg.sender
            ),
            block.timestamp
        );
        return true;
    }

    /// @notice Get Vault balance for a specific token
    /// @param _token Address of the ERC20 compatible token
    function getTokenBalance(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(composableHolding));
    }

    /// @notice External function called by the owner to pause asset withdrawal
    /// @param _token address of the ERC20 token
    function pauseWithdraw(address _token)
        external
        onlySupportedToken(_token)
        onlyOwner
    {
        require(allowToWithdraw[_token], "Already paused");
        delete allowToWithdraw[_token];
    }

    /// @notice External function called by the owner to unpause asset withdrawal
    /// @param _token address of the ERC20 token
    function unpauseWithdraw(address _token)
        external
        onlySupportedToken(_token)
        onlyOwner
    {
        require(!allowToWithdraw[_token], "Already allow");
        allowToWithdraw[_token] = true;
    }

    /// @dev Internal function called when deploy a receipt Receipt token based on already deployed ERC20 token
    function _deployReceipt(address underlyingToken) private returns (address) {
        require(
            address(receiptTokenFactory) != address(0),
            "Receipt token factory not initialized"
        );

        address newReceipt = receiptTokenFactory.createReceipt(
            underlyingToken,
            tokenName
        );
        underlyingReceiptAddress[underlyingToken] = newReceipt;
        emit TokenReceiptCreated(underlyingToken);
        return newReceipt;
    }

    /// @param _token Address of the ERC20 compatible token
    function getReceiptTokenBalance(address _token)
        public
        view
        returns (uint256)
    {
        return
            IReceiptBase(underlyingReceiptAddress[_token]).balanceOf(
                msg.sender
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

    modifier onlySupportedToken(address _tokenAddress) {
        require(
            whitelistedTokens[_tokenAddress] == true &&
                underlyingReceiptAddress[_tokenAddress] != address(0),
            "Token is not supported"
        );
        _;
    }

    modifier notOverMaxCap(address _token, uint256 _amount) {
        uint256 _tokenBalance = getTokenBalance(_token);
        require(
            _tokenBalance.add(_amount) <= maxAssetCap[_token],
            "Amount exceed max cap per asset"
        );
        _;
    }
}