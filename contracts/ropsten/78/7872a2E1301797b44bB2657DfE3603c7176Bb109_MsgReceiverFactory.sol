// SPDX-License-Identifier: MIT
/**
 * @summary: Handles MsgReceiver contract management
 * @author: @gcosmintech
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../interfaces/IMsgReceiverFactory.sol";
import "./MsgReceiver.sol";

contract MsgReceiverFactory is
    IMsgReceiverFactory,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /// @notice relayer address
    address public relayer;

    /// @notice all personas created so far
    mapping(address => address) public personas;

    /// @notice event emitted when a new persona is created
    event PersonaCreated(address indexed user, address indexed persona);

    /// @notice event emitted when persona is deleted
    event PersonaRemoved(address indexed admin, address indexed persona);

    /// @notice event emitted when relayer address is changed
    event RelayerChanged(
        address indexed admin,
        address indexed oldRelayer,
        address indexed newLayer
    );
    event RelayerChangedForPersona(
        address indexed admin,
        address newLayer,
        address indexed persona
    );

    function initialize() public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    /// @notice used to retrieve an existing persona
    /// @param _user persona's owner
    /// @return _user persona's address
    function retrievePersona(address _user)
        external
        view
        override
        returns (address)
    {
        return personas[_user];
    }

    /// @notice used to create a persona for user
    /// @param _user persona's owner
    function createPersona(address _user)
        external
        override
        onlyOwner
        whenNotPaused
        nonReentrant
        validAddress(_user)
        returns (address)
    {
        require(personas[msg.sender] == address(0), "Already created");

        address persona = _user; //TODO: create persona
        emit PersonaCreated(msg.sender, persona);

        return persona;
    }

    /// @notice used to delete an existing persona
    /// @param _user persona's owner
    function removePersona(address _user)
        external
        override
        nonReentrant
        onlyOwnerOrRelayer
        validAddress(_user)
    {
        require(personas[_user] != address(0), "Not found");

        emit PersonaRemoved(msg.sender, personas[_user]);

        delete personas[_user];
    }

    /// @notice sets the relayer address for a persona
    /// @param _persona persona's address
    /// @param _relayer new relayer address
    function updatePersonaRelayer(address _persona, address _relayer)
        external
        nonReentrant
        onlyOwner
        validAddress(_persona)
        validAddress(_relayer)
    {
        MsgReceiver(_persona).updateRelayer(_relayer);
        emit RelayerChangedForPersona(msg.sender, _relayer, _persona);
    }

    /// @notice sets the relayer address
    /// @param _relayer new relayer address
    function setRelayer(address _relayer)
        external
        onlyOwner
        validAddress(_relayer)
    {
        emit RelayerChanged(msg.sender, relayer, _relayer);
        relayer = _relayer;
    }

    /// @notice pauses the contract entirely
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /// @notice unpauses the contract
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    modifier onlyOwnerOrRelayer() {
        require(
            _msgSender() == owner() || _msgSender() == relayer,
            "Only owner or relayer"
        );
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }
}