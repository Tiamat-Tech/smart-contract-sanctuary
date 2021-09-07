// SPDX-License-Identifier: MIT
// @unsupported: ovm
pragma solidity ^0.6.8;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/IBridgeAggregator.sol";
import "../interfaces/IVaultBase.sol";

/// @title BridgeAggregator
/// @notice Composable contract responsible with multiple bridge logic
contract BridgeAggregator is OwnableUpgradeable, IBridgeAggregator {

    address public vaultAddress;

    address public composableHolding;

    mapping(uint256 => address) public supportedBridges;

    function initialize(
        address _composableHolding,
        address _vaultAddress
    ) public initializer {
        __Ownable_init();
        vaultAddress = _vaultAddress;
        composableHolding = _composableHolding;
    }

    /// @notice External function called by admin to add bridge
    /// @param destinationNetwork Chain ID of the destination network
    /// @param bridgeAddress Address of the bridge
    function addBridge(uint256 destinationNetwork, address bridgeAddress)
    external
    override
    onlyOwner
    validAddress(bridgeAddress)
    {
        require(destinationNetwork >= 0, "Invalid destination network");
        require(supportedBridges[destinationNetwork] == address(0), "Bridge already set for the destination");
        supportedBridges[destinationNetwork] = bridgeAddress;
    }

    /// @notice External function called by admin to remove supported bridge
    /// @param destinationNetwork Chain ID of the destination network
    /// @dev destinationNetwork is used to identify the bridge
    function removeBridge(uint256 destinationNetwork)
    external
    onlyOwner
    {
        delete supportedBridges[destinationNetwork];
    }

    /// @notice External function called only by the address of the vault to bridge token to L2
    /// @param destinationNetwork chain id of the destination network
    /// @param receiver Address of the receiver on the L2 network
    /// @param token Address of the ERC20 token
    /// @param amount Amount need to be send
    /// @param _data Additional data that different bridge required in order to mint token
    function bridgeTokens(
        uint256 destinationNetwork,
        address receiver,
        address token,
        uint256 amount,
        bytes calldata _data
    )
    external
    override
    onlyVault
    validAmount(amount)
    {
        address _bridgeAddress = supportedBridges[destinationNetwork];
        require(_bridgeAddress != address(0), "Invalid destination network");
        IERC20(token).transferFrom(composableHolding, address(this), amount);
        SafeERC20.safeApprove(IERC20(token), _bridgeAddress, amount);
        IVaultBase(_bridgeAddress).depositERC20ForAddress(
            amount,
            token,
            _data,
            receiver
        );
        emit AssetSend(receiver, token, amount, destinationNetwork);
    }

    function getTokenBalance(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(composableHolding));
    }

    modifier validAmount(uint256 _value) {
        require(_value > 0, "Invalid amount");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier onlyVault() {
        require(msg.sender == vaultAddress, "Permissions: Only vault allowed");
        _;
    }
}