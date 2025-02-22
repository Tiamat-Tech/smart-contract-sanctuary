// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

contract FeeManagerUpgradeable is Initializable, ContextUpgradeable, AccessControlUpgradeable {
    struct Fees {
        uint256 _transferFee;
        uint256 _exchangeFee;
        bool accepted;
    }

    address private handler;

    // destinationChainID => feeTokenAddress => Fees
    mapping(uint8 => mapping(address => Fees)) private _fees;

    modifier isHandler() {
        require(handler == _msgSender(), "Fee Manager : Only Router Handlers can set Fees");
        _;
    }

    function __FeeManagerUpgradeable_init(address handlerAddress) internal initializer {
        __AccessControl_init();
        __Context_init_unchained();

        handler = handlerAddress;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function initialize(address handlerAddress) external initializer {
        __FeeManagerUpgradeable_init(handlerAddress);
    }

    function __FeeManagerUpgradeable_init_unchained() internal initializer {}

    event FeeUpdated(
        uint8 destinationChainID,
        address feeTokenAddress,
        uint256 transferFee,
        uint256 exchangeFee,
        bool accepted
    );

    /**
        @notice Used to fetch handler address.
        @notice Only callable by admin or Fee Setter.
     */
    function fetchHandler() public view returns (address) {
        return handler;
    }

    /**
        @notice Used to setup handler address.
        @notice Only callable by admin or Fee Setter.
        @param  _handler Address of the new handler.
     */
    function setHandler(address _handler) public onlyRole(DEFAULT_ADMIN_ROLE) {
        handler = _handler;
    }

    /**
        @notice Used to set deposit fee.
        @notice Only callable by admin or Fee Setter.
        @param  destinationChainID id of the destination chain.
        @param  feeTokenAddress address of the fee token.
        @param  transferFee Value {_transferFee} will be updated to.
        @param  exchangeFee Value {_exchangeFee} will be updated to.
        @param  accepted accepted status of the token as fee.
     */
    function setFee(
        uint8 destinationChainID,
        address feeTokenAddress,
        uint256 transferFee,
        uint256 exchangeFee,
        bool accepted
    ) public isHandler {
        require(feeTokenAddress != address(0), "setFee: address can't be null");
        Fees storage fees = _fees[destinationChainID][feeTokenAddress];
        fees._transferFee = transferFee;
        fees._exchangeFee = exchangeFee;
        fees.accepted = accepted;
        emit FeeUpdated(destinationChainID, feeTokenAddress, fees._transferFee, fees._exchangeFee, fees.accepted);
    }

    /**
        @notice Used to get deposit fee.
        @param  destinationChainID id of the destination chain.
        @param  feeTokenAddress address of the fee token.
    */
    function getFee(uint8 destinationChainID, address feeTokenAddress) public view virtual returns (uint256, uint256) {
        require(_fees[destinationChainID][feeTokenAddress].accepted, "FeeManager: fees not set for this token");
        Fees storage fees = _fees[destinationChainID][feeTokenAddress];
        return (fees._transferFee, fees._exchangeFee);
    }

    function withdrawFee(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external isHandler {
        IERC20Upgradeable(tokenAddress).transfer(recipient, amount);
    }
}