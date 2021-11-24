pragma solidity ^0.8.0;
// Copyright 2021 Keyko GmbH.
// SPDX-License-Identifier: (CC-BY-NC-ND-3.0)
// Code and docs are CC-BY-NC-ND-3.0

import "./IEthAnchorRouter.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title Yield Aggregator
 *
 * @dev First yield aggregator which interact with EthAnchor
 *
 */

contract YieldAggregator is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant BACKEND_ADMIN_ROLE =
        keccak256("BACKEND_ADMIN_ROLE");

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Address of the ERC20 used for yielding
     */
    IERC20Upgradeable public inputToken;
    address public backendAddress;
    IEthAnchorRouter public ethAnchorRouter;

    /**
     * @notice Emmited when a user deposits USDC tokens
     * @param account address of the account which has deposited the liquidity
     * @param amount_usdc amount of USDC tokens deposited by the user
     */
    event Deposit(address account, uint256 amount_usdc);

    /**
     * @notice Emmited when the vault withdraws USDC tokens
     * @param account address of the vault
     * @param amount_usdc amount of USDC tokens that has been withdrawed
     */
    event Withdraw(address account, uint256 amount_usdc);

    /**
     * @notice initialize init the contract with the following parameters
     * @dev this function is called only once during the contract initialization
     * @param _inputTokenAddress USDC Token contract address
     * @param _backendAddress addres of Chainlink Defender
     */
    function initialize(address _inputTokenAddress, address _backendAddress)
        external
        initializer
    {
        inputToken = IERC20Upgradeable(_inputTokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        backendAddress = _backendAddress;
        _setupRole(BACKEND_ADMIN_ROLE, backendAddress);
        ethAnchorRouter = IEthAnchorRouter(
            0x7537aC093cE1315BCE08bBF0bf6f9b86B7475008
        );
    }

    /**
     * @notice deposits USDC tokens to this contract
     * @dev anyone can deposit founds to the Yield Source
     * @param _amount amount of USDC tokens that are going to be deposited
     */
    function deposit(uint256 _amount) external {
        inputToken.safeTransferFrom(msg.sender, address(this), _amount);
        inputToken.approve(address(ethAnchorRouter), _amount);
        ethAnchorRouter.depositStable(_amount);

        emit Deposit(_msgSender(), _amount);
    }

    /**
     * @dev withdraw funds from the EthAnchor
     * @param _account Address to receive resulting wrapped UST
     * @param _amount Amount of wrapped aUST to redeem
     */
    function withdraw(address _account, uint256 _amount)
        external
        onlyRole(BACKEND_ADMIN_ROLE)
    {
        // Burn Mechanism need to be added.
        ethAnchorRouter.redeemStable(_account, _amount);
        emit Withdraw(_account, _amount);
    }

    /**
     * @notice used to change the address of the Vault contract
     * @param _backendAddress new address of the Chainlink Defender
     */
    function setBackendAddress(address _backendAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _backendAddress != address(0),
            "Reserve: Backend contract address cannot be address 0!"
        );
        backendAddress = _backendAddress;
        grantRole(BACKEND_ADMIN_ROLE, backendAddress);
    }
}