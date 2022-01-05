//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./ICurve.sol";
import "./ISwapper.sol";

contract SwapCurve is
    ISwapper,
    Initializable,
    AccessControlUpgradeable
{
    bytes32 public constant BACKEND_ADMIN_ROLE =
        keccak256("BACKEND_ADMIN_ROLE");

    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public ustToken;
    IERC20Upgradeable public usdcToken;

    address public ustPoolSwapAddress;
    address public ustTokenAddress;
    address public usdcTokenAddress;
    address public backendAddress;

    struct Route {
        int128 _fromIx;
        int128 _toIx;
    }

    mapping(address => mapping(address => Route)) private routes;

    /**
     * @notice initialize init the contract with the following parameters
     * @dev this function is called only once during the contract initialization
     * @param _ustPoolSwapAddress Curve's Pool Address for swapping UST and USDC back and forth
     * @param _ustTokenAddress Contract UST token address
     * @param _usdcTokenAddress Contract USDC token address
     * @param _backendAddress addres of Chainlink Defender
     */
    function initialize(
        address _ustPoolSwapAddress,
        address _ustTokenAddress,
        address _usdcTokenAddress,
        address _backendAddress
    ) external initializer {
        ustPoolSwapAddress = _ustPoolSwapAddress;
        ustToken = IERC20Upgradeable(_ustTokenAddress);
        usdcToken = IERC20Upgradeable(_usdcTokenAddress);
        backendAddress = _backendAddress;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(BACKEND_ADMIN_ROLE, backendAddress);

        // sets up routes for exchanging tokens
        setRoutes();
    }

    function setRoutes() internal {
        routes[address(ustToken)][address(usdcToken)] = Route(0, 2);
        routes[address(usdcToken)][address(ustToken)] = Route(2, 0);
    }

    /**
     * @dev Swaps two tokens (USDC and wUST) using Curve.fi
     * @param _from: origin token to be swapped by _to token [USDC, UST]
     * @param _to: detiny token to be swapped from _from token [UST, USDC]
     * @param _amount: amount of _from tokens to be exchanged
     * @param _minAmountOut: minimun amount of _to tokens to received (not used)
     * @param _beneficiary: other than contract's address as receiver (not used)
     */
    function swapToken(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _minAmountOut,
        address _beneficiary
    ) public override {
        Route memory route = routes[_from][_to];
        require(
            route._fromIx != 0 || route._toIx != 0,
            "SwapCurve: Indexes not recognized."
        );

        uint256 balanceToken = IERC20Upgradeable(_from).balanceOf(
            address(this)
        );
        require(
            balanceToken >= _amount,
            "SwapCurve: Not enough balance to start swap."
        );

        IERC20Upgradeable(_from).approve(ustPoolSwapAddress, _amount);

        ICurveEx(ustPoolSwapAddress).exchange_underlying(
            int128(route._fromIx),
            int128(route._toIx),
            _amount,
            0
        );
    }

    /**
     * @notice used to change the address of the Curve's UST Pool Swap Address
     * @param _ustPoolSwapAddress new address of the backend admin
     */
    function setUstPoolSwapAddress(address _ustPoolSwapAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _ustPoolSwapAddress != address(0),
            "SwapCurve: Curve's UST Pool Swap Address cannot be address 0!"
        );
        ustPoolSwapAddress = _ustPoolSwapAddress;
    }

    /**
     * @notice used to change the address of the Vault contract
     * @param _backendAddress new address of the backend admin
     */
    function setBackendAddress(address _backendAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _backendAddress != address(0),
            "SwapCurve: Backend contract address cannot be address 0!"
        );
        backendAddress = _backendAddress;
        grantRole(BACKEND_ADMIN_ROLE, backendAddress);
    }
}