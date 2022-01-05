// SPDX-License-Identifier: (CC-BY-NC-ND-3.0)
// Code and docs are CC-BY-NC-ND-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title Vault
 * @dev Contract in charge of holding usdc tokens and depositing them to Yield Aggregator
 *
 */

interface IYieldAggregator {
    function deposit(uint256 _amount) external;
}

contract Vault is Initializable, AccessControlUpgradeable {
    bytes32 public constant BACKEND_ADMIN_ROLE =
        keccak256("BACKEND_ADMIN_ROLE");

    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable private usdcToken;

    /**
     * @notice Emitted when USDC tokens are moved to Yield Aggregator contract
     * @param _account msg.sender or who decided to move the funds
     * @param amount_usdc is the amount of tokens being moved
     */
    event FundsMovedToAggregator(address _account, uint256 amount_usdc);

    /**
     * @dev address of the Chainlink Defender
     */
    address private backendAddress;
    /**
     * @dev address of the contract responsible for yielding
     */
    address private yieldSourceAddress;

    /**
     * @notice initialize init the contract with the following parameters
     * @dev this function is called only once during the contract initialization
     * @param _usdcTokenAddress USDC token contract address
     * @param _backendAddress address of the Chainlink Defender
     * @param _yieldSourceAddress address of the contract responsible for yielding
     */
    function initialize(
        address _usdcTokenAddress,
        address _backendAddress,
        address _yieldSourceAddress
    ) external initializer {
        require(
            _usdcTokenAddress != address(0),
            "Vault: USDC token address cannot be address 0!"
        );

        usdcToken = IERC20Upgradeable(_usdcTokenAddress);
        backendAddress = _backendAddress;
        yieldSourceAddress = _yieldSourceAddress;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(BACKEND_ADMIN_ROLE, _backendAddress);
    }

    /**
     * @notice Transfers "amount_usdc" of tokens to Yield Aggregator contract
     * @param amount_usdc is the amount of USDC tokens transferred to Yield Aggregator contract
     */
    function moveFundsToAggregator(uint256 amount_usdc)
        external
        onlyRole(BACKEND_ADMIN_ROLE)
    {
        // approve usdc to Vault Reserve from user or msg.sender

        // transerFrom sender to Vault Reserver Contract
        usdcToken.safeTransferFrom(_msgSender(), address(this), amount_usdc);

        // approve to Yield Aggregator
        usdcToken.approve(yieldSourceAddress, amount_usdc);

        // call deposit from Yield Aggregator Contract
        IYieldAggregator(yieldSourceAddress).deposit(amount_usdc);

        emit FundsMovedToAggregator(_msgSender(), amount_usdc);
    }

    /**
     * @notice used to change the address of the Chainnlink Defnder
     * @param _backendAddress new address of the Chainlink Defender
     */
    function setBackendAddress(address _backendAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _backendAddress != address(0),
            "Vault: Backend contract address cannot be address 0!"
        );
        backendAddress = _backendAddress;
        grantRole(BACKEND_ADMIN_ROLE, backendAddress);
    }

    /**
     * @notice used to change the address of the contract responsible with yielding
     * @param _yieldSourceAddress new address of the contract responsible with yielding
     */
    function setYieldSourceAddress(address _yieldSourceAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _yieldSourceAddress != address(0),
            "Vault: Yield Source contract address cannot be address 0!"
        );
        yieldSourceAddress = _yieldSourceAddress;
    }

    function _testWithdrawAllTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
        usdcToken.transfer(_msgSender(), usdcToken.balanceOf(address(this)));
    }
}