// SPDX-License-Identifier: (CC-BY-NC-ND-3.0)
// Code and docs are CC-BY-NC-ND-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {IEthAnchorRouter} from "./IEthAnchorRouter.sol";
import {ISwapper} from "../swap/ISwapper.sol";

/**
 * @title Yield Aggregator
 * @dev Interacts with Eth Anchor for token yielding
 */

contract YieldAggregator is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    bytes32 public constant BACKEND_ADMIN_ROLE =
        keccak256("BACKEND_ADMIN_ROLE");

    using SafeERC20Upgradeable for IERC20Upgradeable;

    //tokens
    IERC20Upgradeable public usdcToken;
    IERC20Upgradeable public ustToken; // wUST wrapped UST token
    IERC20Upgradeable public aUstToken; // aUST wrapped anchor UST token

    // backend
    address public backendAddress;
    address public vaultReserveAddressContract;
    IEthAnchorRouter public ethAnchorRouter;
    ISwapper public swapper;

    // Add the whitelist functionality
    bool public whitelisting;
    mapping(address => bool) private _isWhiteListed;

    modifier whiteListedOnly() {
        if (whitelisting) {
            require(
                _isWhiteListed[msg.sender],
                "YieldAggregator: Not whitelisted"
            );
            _;
        } else {
            _;
        }
    }

    /**
     * @notice Emmited when a user deposits USDC tokens
     * @param account address of the account which has deposited the liquidity
     * @param amount_usdc amount of USDC tokens deposited by the user
     * @param amount_ust amount of UST tokens after swapped
     */
    event Deposit(address account, uint256 amount_usdc, uint256 amount_ust);

    /**
     * @notice Emmited when a withdraw from Eth Anchor is initiated
     * @param account address of the account which has initiated the withdraw
     * @param amount_aust amount of UST tokens to claim from Eth Anchor
     */
    event InitWithdraw(address account, uint256 amount_aust);

    /**
     * @notice Emmitted when the Yield Aggregator finishes the initiated withdraw
     * @param _toAccount is the destination address
     * @param amount_ust amount of wUST tokens that will be withdrawn
     * @param amount_usdc amount of USDC tokens to be sent to '_toAccount'
     */
    event FinishWithdraw(
        address _toAccount,
        uint256 amount_ust,
        uint256 amount_usdc
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
     * @notice initialize init the contract with the following parameters
     * @dev this function is called only once during the contract initialization
     * @param _ustTokenAddress wUST Token contract address
     * @param _aUstToken aUST Token contract address
     * @param _usdcTokenAddress USDC Token contract address
     * @param _backendAddress address of Chainlink Defender
     * @param _ethAnchorRouterAddress address of Eth Anchor Router Contract
     * @param _swapperAddressContract address of Swapper Contract [Curve.fi, Uniswap]
     */
    function initialize(
        address _ustTokenAddress,
        address _aUstToken,
        address _usdcTokenAddress,
        address _backendAddress,
        address _ethAnchorRouterAddress,
        address _swapperAddressContract
    ) external initializer {
        // tokens
        usdcToken = IERC20Upgradeable(_usdcTokenAddress);
        ustToken = IERC20Upgradeable(_ustTokenAddress);
        aUstToken = IERC20Upgradeable(_aUstToken);

        // backend
        backendAddress = _backendAddress;

        // swapper
        swapper = ISwapper(_swapperAddressContract);

        // yield
        ethAnchorRouter = IEthAnchorRouter(_ethAnchorRouterAddress);

        // roles
        _setupRole(BACKEND_ADMIN_ROLE, backendAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        // whitelist
        _isWhiteListed[backendAddress] = true;
        _isWhiteListed[_msgSender()] = true;

        // pausable set up
        __Pausable_init();
    }

    /**
     * @notice deposits USDC tokens to this contract
     * @dev anyone can deposit founds to the Yield Source
     * @param _amount amount of USDC tokens that are going to be deposited
     */
    function deposit(uint256 _amount) external whiteListedOnly whenNotPaused {
        // approve usdc to yield aggregator from user

        require(
            usdcToken.balanceOf(_msgSender()) >= _amount,
            "Yield Aggregator: Not enough balance."
        );
        // tranferFrom sender to yield aggreagor
        usdcToken.safeTransferFrom(_msgSender(), address(this), _amount);
        // approve usdc to swapper (Curve or Uniswap) from yield aggregator
        usdcToken.approve(address(swapper), _amount);
        // swap through swapper (Curve or Uniswap) usdc -> wUst
        swapper.swapToken(
            address(usdcToken),
            address(ustToken),
            _amount,
            1,
            address(this)
        );
        // get all wUST at yield aggregator
        uint256 _allwUST = ustToken.balanceOf(address(this));
        // approve (all) wUST to ethanchor from yield aggregator
        ustToken.approve(address(ethAnchorRouter), _allwUST);
        // deposit (all) wUst to ethanchor
        ethAnchorRouter.depositStable(_allwUST);

        emit Deposit(_msgSender(), _amount, _allwUST);
    }

    /**
     * @notice Initiates withdraw of wUST (plus accrued interest) by claiming aUST tokens from EthAnchor
     * EthAnchor will send wUST at unspecified time to Yield Aggregator
     * @param _amount: amount of aUST to redeem from EthAnchor
     */
    function startRedeemOfaUST(uint256 _amount)
        public
        onlyRole(BACKEND_ADMIN_ROLE)
        whenNotPaused
    {
        // approve aUST to Eth Anchor from Yield Aggregator
        aUstToken.safeApprove(address(ethAnchorRouter), _amount);

        // initiates withdraw of aUST from eth anchor to Yield Aggregator
        ethAnchorRouter.redeemStable(_amount);

        emit InitWithdraw(address(this), _amount);
    }

    /**
     * @notice All balance is wUST tokens is converted to USDC and sent to Vault Reserve
     * wUST is received an unspecified amount of time after redeeming aUST from EthAnchor
     * Once wUST arrives at Yield Aggregator, all of it is send to Vault after swapping
     */
    function swapToUsdcSendToVault()
        public
        onlyRole(BACKEND_ADMIN_ROLE)
        whenNotPaused
    {
        // get all wUST from Yield Aggregator
        uint256 _allUst = ustToken.balanceOf(address(this));
        require(_allUst > 0, "Yield Aggregator: Balance of wUST is zero.");

        // approve wUST to swapper (Curve or Uniswap) from yield aggregator
        ustToken.approve(address(swapper), _allUst);

        // swap through swapper (Curve or Uniswap) wUst -> usdc
        swapper.swapToken(
            address(ustToken),
            address(usdcToken),
            _allUst,
            1,
            address(this)
        );

        // Yield Aggregator balance of USDC
        uint256 _allUSDC = usdcToken.balanceOf(address(this));

        // send USDC to Vault Reserve
        usdcToken.transfer(vaultReserveAddressContract, _allUSDC);

        emit FinishWithdraw(vaultReserveAddressContract, _allUst, _allUSDC);
    }

    /**
     * @notice used to change the address of the Swapper Contract
     * @param _vaultReserveAddressContract new address of the Vault Reserve Contract
     */
    function setVaultReserveAddress(address _vaultReserveAddressContract)
        external
        onlyRole(BACKEND_ADMIN_ROLE)
    {
        require(
            _vaultReserveAddressContract != address(0),
            "Yield Aggreagator: Vault Reserver address cannot be zero. "
        );
        vaultReserveAddressContract = _vaultReserveAddressContract;
    }

    /**
     * @notice used to change the address of the Swapper Contract
     * Swapper Contracts: SwapCurve.sol or UniswapRouter.sol
     * @param _swapperAddressContract new address of the Swapper Contract
     */
    function setSwapperContract(address _swapperAddressContract)
        external
        onlyRole(BACKEND_ADMIN_ROLE)
    {
        require(
            _swapperAddressContract != address(0),
            "Yield Aggreagator:  Swapper address cannot be zero."
        );
        swapper = ISwapper(_swapperAddressContract);
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
            "Yield Aggreagator: Backend address cannot be zero."
        );
        backendAddress = _backendAddress;
        grantRole(BACKEND_ADMIN_ROLE, backendAddress);
    }

    /**
     * @notice used to enable or disable the whitelisting
     * @param _whitelisting True/False for enable/disable the whitelisting
     */
    function setWhitelisting(bool _whitelisting)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        whitelisting = _whitelisting;
    }

    function _testWithdrawAllTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
        usdcToken.transfer(_msgSender(), usdcToken.balanceOf(address(this)));
        ustToken.transfer(_msgSender(), ustToken.balanceOf(address(this)));
        aUstToken.transfer(_msgSender(), aUstToken.balanceOf(address(this)));
    }

    function version() public pure virtual returns (string memory) {
        return "1.0.0";
    }
}