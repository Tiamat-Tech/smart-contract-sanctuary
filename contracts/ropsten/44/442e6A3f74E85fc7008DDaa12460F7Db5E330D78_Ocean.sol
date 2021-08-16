// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

// To replace currency with address
contract Ocean is AccessControl, ReentrancyGuard, Pausable {
    // A helper to make safe the interaction with someone else’s ERC20 token, in your contracts.
    using SafeERC20 for IERC20;

    // Order of variable is important for storage slot usage

    /* ====== OCEAN INFO (Mutable) ====== */
    mapping(address => uint256) public reserves; // track qty of currency that can be borrowed

    mapping(address => mapping(address => uint256)) public userCollaterals; // track user collaterals
    mapping(address => mapping(address => uint256)) public userBorrows; // track user borrow
    mapping(address => address[]) public userBorrowedCurrencies;
    mapping(address => address[]) public userCollateralCurrencies;

    /* ====== ROLES ====== */
    // Ocean Master(OM) can supply to the pools in his/her own ocean’s reserves
    bytes32 public constant OM_ROLE = keccak256("OCEANMASTER");

    // Konomi Deployment account
    // bytes32 public constant ADMIN_ROLE = keccak256("KONOADMIN");

    /* ====== OCEAN INFO (Immutable) ====== */
    uint256 public oceanId; // The id of the Ocean. This id is assigned during deployment.
    mapping(address => bool) public collaterals; // List of allowed collaterals
    uint32 public liquidationThreshold; // Liquidation threshold
    uint256 public immutable month = 172800; // roughly 172800 blocks per month

    /* ====== POOL INFO ====== */
    struct Pool {
        address currency;
        uint32 interestRate;
    }

    address internal liquidatorAddress;

    constructor(
        address _omAddress,
        uint256 _oceanId,
        address[] memory _collaterals,
        uint32 _liquidationThreshold
    ) {
        _setupRole(OM_ROLE, _omAddress);
        oceanId = _oceanId;
        liquidationThreshold = _liquidationThreshold;

        for (uint256 i = 0; i < _collaterals.length; i++) {
            collaterals[_collaterals[i]] = true;
        }

        // setup interest rate - floating/fixed
    }

    modifier onlyOceanMaster() {
        require(AccessControl.hasRole(OM_ROLE, msg.sender), "Invalid role");
        _;
    }

    modifier validLease(uint256 _leaseEnd) {
        require(_leaseEnd >= block.number, "Invalid lease end");
        require(block.number + month <= _leaseEnd, "Lease too short");
        _;
    }

    modifier hasEnough(address _currency, uint256 _amount) {
        require(
            _amount <= IERC20(_currency).balanceOf(msg.sender),
            "Insufficient currency"
        );
        _;
    }

    function supplyReserve(address _currency, uint256 _amount)
        external
        onlyOceanMaster
        nonReentrant
        whenNotPaused
    {
        if (_amount > 0) {
            IERC20(_currency).safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );

            // TODO: if lease end - dont allow om to supply
            // TODO: no withdrawal allowed - release to om after lease

            reserves[_currency] += _amount;
        }
    }

    // withdrawlReserve?

    function supplyCollateral(address _currency, uint256 _amount)
        external
        hasEnough(_currency, _amount)
        nonReentrant
        whenNotPaused
    {
        require(collaterals[_currency], "Invalid collateral");

        IERC20(_currency).safeTransferFrom(msg.sender, address(this), _amount);

        userCollaterals[msg.sender][_currency] += _amount;
    }

    function getUserCollateral(address _currency)
        external
        view
        returns (uint256)
    {
        return userCollaterals[msg.sender][_currency];
    }

    function withdrawCollateral(address _currency, uint256 _amount)
        external
        nonReentrant
        whenNotPaused
    {
        require(
            userCollaterals[msg.sender][_currency] >= _amount,
            "Not enough collateral"
        );
        // TODO: allow withdraw if liquidation will not be triggered

        IERC20(_currency).safeTransfer(address(this), _amount);

        userCollaterals[msg.sender][_currency] -= _amount;
    }

    function borrow(address _currency, uint256 _amount)
        external
        nonReentrant
        whenNotPaused
    {
        // TODO: allow borrow if liquidation will not be triggered
        require(reserves[_currency] > 0, "Reserve empty");
        require(reserves[_currency] > _amount, "Reserve insufficient");

        IERC20(_currency).safeTransfer(msg.sender, _amount);

        userBorrows[msg.sender][_currency] += _amount;
        reserves[_currency] -= _amount;
    }

    function repay(address _currency, uint256 _amount)
        external
        hasEnough(_currency, _amount)
        nonReentrant
        whenNotPaused
    {
        // to remove?
        require(userBorrows[msg.sender][_currency] >= _amount, "Over repay");
        IERC20(_currency).safeTransferFrom(msg.sender, address(this), _amount);

        userBorrows[msg.sender][_currency] -= _amount;
        reserves[_currency] += _amount;
    }

    function getUserBorrows(address _currency) external view returns (uint256) {
        return userBorrows[msg.sender][_currency];
    }

    /**
     * @notice liquidate a borrower collateral which is unhealthy
     * @param collateralToken Address of collateral token
     * @param borrowToken Address of borrow token
     * @param user Address of collateral owner
     */
    function liquidation(
        address collateralToken,
        address borrowToken,
        address user
    ) external whenNotPaused {
        // TODO check collateralToken, borrowToken
        address liquidator = liquidatorAddress;

        (bool success, bytes memory result) = liquidator.delegatecall(
            abi.encodeWithSignature(
                "liquidate(uint8,address,address,uint256,uint256)",
                liquidationThreshold,
                collateralToken,
                borrowToken,
                userCollaterals[user][collateralToken],
                userBorrows[user][borrowToken]
            )
        );

        require(success, "Liquidation fail.");

        (uint256 liquidateAmount, string memory returnMessage) = abi.decode(
            result,
            (uint256, string)
        );

        require(liquidateAmount > 0, string(abi.encodePacked(returnMessage)));

        userCollaterals[user][collateralToken] -= liquidateAmount;
        IERC20(collateralToken).safeTransferFrom(
            address(this),
            msg.sender,
            liquidateAmount
        );
    }
}