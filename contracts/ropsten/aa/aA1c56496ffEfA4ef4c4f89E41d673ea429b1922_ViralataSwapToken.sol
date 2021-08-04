// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract ViralataSwapToken is ERC2771Context, ERC20, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");
    bytes32 public constant TAKE_FEE_ROLE = keccak256("TAKE_FEE_ROLE");

    uint256 private _cap = 2000000000 * 10**decimals(); // 2 billion tokens is maximum supply
    uint256 private _initialSupply = 200000 * 10**decimals(); // 200,000 tokens is the initial supply
    uint256 public taxFee = 50;

    bool public takeFee = true;
    address public feeAccount; // Account or contract for taking token fees

    event FeeChanged(address indexed sender, uint256 oldFee, uint256 newFee);
    event FeeDisabled(address indexed sender);
    event FeeEnabled(address indexed sender);
    event TokensRescued(address indexed sender, address indexed token, uint256 value);
    event FeeAccountChanged(address indexed sender, address from, address to);

    function _msgSender() internal view virtual override(ERC2771Context, Context) returns (address sender) { return msg.sender; }

    function _msgData() internal view virtual override(ERC2771Context, Context) returns (bytes memory) { return msg.data; }

    constructor(address _forwarder) ERC20("ViralataSwap Token", "AURO") ERC2771Context(_forwarder) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(RESCUER_ROLE, _msgSender());
        _setRoleAdmin(TAKE_FEE_ROLE, DEFAULT_ADMIN_ROLE);
        _mint(_msgSender(), _initialSupply);
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        (uint256 actualAmount, uint256 fee) = _calculateFee(sender, recipient, amount);
        _transfer(sender, recipient, actualAmount);
        if (fee > 0) _transfer(sender, feeAccount, fee);

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Calculate fees on transfers
     */
    function _calculateFee(
        address from,
        address to,
        uint256 amount
    ) private view returns (uint256, uint256) {
        if (takeFee && (hasRole(TAKE_FEE_ROLE, from) || hasRole(TAKE_FEE_ROLE, to))) {
            uint256 fee = amount.mul(taxFee).div(10000);
            uint256 realAmount = amount.sub(fee);
            return (realAmount, fee);
        } else {
            return (amount, 0);
        }
    }

    function setTaxFeePercent(uint256 _taxFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldFee = taxFee;
        taxFee = _taxFee;

        emit FeeChanged(msg.sender, oldFee, _taxFee);
    }

    function rescueTokens(IERC20 token, uint256 value) external onlyRole(RESCUER_ROLE) {
        token.transfer(_msgSender(), value);

        emit TokensRescued(msg.sender, address(token), value);
    }

    function disableFee() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(takeFee, "Fee is already disabled");
        takeFee = false;

        emit FeeDisabled(msg.sender);
    }

    function enableFee() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!takeFee, "Fee is already enabled");
        takeFee = true;

        emit FeeEnabled(msg.sender);
    }

    function changeFeeAccount(address newFeeAccount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address oldFeeAccount = feeAccount;
        feeAccount = newFeeAccount;

        emit FeeAccountChanged(msg.sender, oldFeeAccount, newFeeAccount);
    }
}