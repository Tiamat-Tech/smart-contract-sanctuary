// SPDX-License-Identifier: MIT
/**
 * @summary: Initiate cross chain function calls for whitelisted networks
 * @author: @gcosmintech
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/IMsgSender.sol";

contract MsgSender is
    IMsgSender,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice used for generating the unique id
    uint256 public nonce;

    /// @notice pausable per network
    mapping(uint256 => bool) public pausedNetwork;

    /// @notice networks that the contract is able to interact with
    mapping(uint256 => bool) public whitelistedNeworks;

    /// @notice true when a call was successfully initiated
    mapping(bytes32 => bool) public hasBeenForwarded;

    /// @notice last initiated call
    bytes32 public lastForwardedCall;

    /// @notice event emitted when a new remote chain id is added to the whitelist
    event NetworkAddedToWhitelist(address indexed admin, uint256 chainId);

    /// @notice event emitted when an existing remote chain id is removed from the whitelist
    event NetworkRemovedFromWhitelist(address indexed admin, uint256 chainId);

    /// @notice event emitted when an whitelisted remote chain id is paused
    event PauseNetwork(address indexed admin, uint256 networkID);

    /// @notice event emitted when an whitelisted remote chain id is unpaused
    event UnpauseNetwork(address indexed admin, uint256 networkID);

    /// @notice event emitted when a cross chain call is initiated
    event CallInitiated(address indexed user, uint256 remoteNetworkId);

    /// @notice event emitted when airdropped tokens are saved from the contract
    event FundsSaved(
        address indexed admin,
        address indexed receiver,
        address indexed token,
        uint256 amount
    );

    /// @notice event emitted when a call si forwarded
    event ForwardCall(
        address indexed user,
        bytes32 id,
        uint256 chainId,
        address indexed destinationContract,
        bytes methodData
    );

    function initialize() public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    /* WIP - ignore this method */
    /// @notice initiates a new cross function call; fees will be taken on the destination layer to avoid rebalancing and user has to pre-fund his MsgReceiver contract
    /// @param _chainId destination chain id
    /// @param _destinationContract contract you need to call on the other layer
    /// @param _methodData encoded data used to call the contract on the other layer
    function registerCrossFunctionCall(
        uint256 _chainId,
        address _destinationContract,
        bytes calldata _methodData
    )
        external
        override
        nonReentrant
        onlyWhitelistedNetworks(_chainId)
        onlyUnpausedNetworks(_chainId)
        whenNotPaused
    {
        bytes32 id = _generateId();

        //shouldn't happen
        require(hasBeenForwarded[id] == false, "Call already forwarded");
        require(lastForwardedCall != id, "Forwarded last time");

        lastForwardedCall = id;
        hasBeenForwarded[id] = true;

        emit ForwardCall(
            msg.sender,
            id,
            _chainId,
            _destinationContract,
            _methodData
        );
    }

    /// @notice used to retrieve airdropped tokens from the contract
    /// @param _token token address
    /// @param _receiver funds receiver
    function saveAirdroppedFunds(address _token, address _receiver)
        external
        onlyOwner
        validAddress(_token)
    {
        uint256 balance = IERC20Upgradeable(_token).balanceOf(address(this));
        require(balance > 0, "No balance");

        IERC20Upgradeable(_token).safeTransfer(_receiver, balance);

        emit FundsSaved(msg.sender, _receiver, _token, balance);
    }

    /// @notice adds a remote chain id to the whitelist
    /// @param _chainId network id
    function addNetwork(uint256 _chainId) external onlyOwner {
        require(whitelistedNeworks[_chainId] == false, "Already whitelisted");

        uint256 currentChain = 0;
        assembly {
            currentChain := chainid()
        }
        require(_chainId > 0, "Invalid chain");
        require(currentChain != _chainId, "Cannot add the same chain");

        whitelistedNeworks[_chainId] = true;
        pausedNetwork[_chainId] = false;

        emit NetworkAddedToWhitelist(msg.sender, _chainId);
    }

    /// @notice removes a remote chain id from the whitelist
    /// @param _chainId network id
    function removeNetwork(uint256 _chainId) external onlyOwner {
        require(whitelistedNeworks[_chainId] == true, "Not whitelisted");
        delete whitelistedNeworks[_chainId];
        delete pausedNetwork[_chainId];
        emit NetworkRemovedFromWhitelist(msg.sender, _chainId);
    }

    /// @notice pauses a whitelisted remote chain id
    /// @param _chainId network id
    function pauseNetwork(uint256 _chainId)
        external
        onlyOwner
        onlyUnpausedNetworks(_chainId)
        onlyWhitelistedNetworks(_chainId)
    {
        pausedNetwork[_chainId] = true;
        emit PauseNetwork(msg.sender, _chainId);
    }

    /// @notice unpauses a whitelisted remote chain id
    /// @param _chainId network id
    function unpauseNetwork(uint256 _chainId)
        external
        onlyOwner
        onlyPausedNetworks(_chainId)
        onlyWhitelistedNetworks(_chainId)
    {
        pausedNetwork[_chainId] = false;
        emit UnpauseNetwork(msg.sender, _chainId);
    }

    /// @notice pauses the contract entirely
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /// @notice unpauses the contract
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    function _generateId() private returns (bytes32) {
        nonce = nonce + 1;
        return keccak256(abi.encodePacked(block.number, address(this), nonce));
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier onlyPausedNetworks(uint256 _network) {
        require(pausedNetwork[_network] == false, "Netwok not paused");
        _;
    }
    modifier onlyUnpausedNetworks(uint256 _network) {
        require(pausedNetwork[_network] == true, "Netwok is not active");
        _;
    }

    modifier onlyWhitelistedNetworks(uint256 _network) {
        require(whitelistedNeworks[_network] == true, "Unknown network");
        _;
    }
}