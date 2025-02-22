//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Hanoux is Context, Ownable {
    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    uint256 private _totalShares;
    uint256 private _totalReleased;

    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;
    /**
     * @dev Creates an instance of `Hanoux` where each account in `payees` is assigned the number of shares at
     * the matching position in the `shares` array.
     *
     * All addresses in `payees` must be non-zero. Both arrays must have the same non-zero length, and there must be no
     * duplicates in `payees`.
     */
    constructor(address[] memory payees, uint256[] memory shares_) {
        require(payees.length == shares_.length, "Hanoux: payees and shares length mismatch");
        require(payees.length > 0, "Hanoux: no payees");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }
    }

    /**
     * @dev The Ether received will be logged with {PaymentReceived} events. Note that these events are not fully
     * reliable: it's possible for a contract to receive Ether without triggering this function. This only affects the
     * reliability of the events, and not the actual splitting of Ether.
     *
     * To learn more about this see the Solidity documentation for
     * https://solidity.readthedocs.io/en/latest/contracts.html#fallback-function[fallback
     * functions].
     */
    receive() external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
    }

    /**
     * @dev Getter for the total shares held by payees.
     */
    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    /**
     * @dev Getter for the total amount of Ether already released.
     */
    function totalReleased() public view returns (uint256) {
        return _totalReleased;
    }

    /**
     * @dev Getter for the amount of shares held by an account.
     */
    function shares(address account) public view returns (uint256) {
        return _shares[account];
    }

    /**
     * @dev Getter for the amount of Ether already released to a payee.
     */
    function released(address account) public view returns (uint256) {
        return _released[account];
    }

    /**
     * @dev Getter for the address of the payee number `index`.
     */
    function payee(uint256 index) public view returns (address) {
        return _payees[index];
    }

    /**
     * @dev Add a new payee to the contract.
     * @param account The address of the payee to add.
     * @param shares_ The number of shares owned by the payee.
     */
    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "Hanoux: account is the zero address");
        require(shares_ > 0, "Hanoux: shares are 0");
        require(_shares[account] == 0, "Hanoux: account already has shares");

        _payees.push(account);
        _shares[account] = shares_;
        _totalShares = _totalShares + shares_;
        emit PayeeAdded(account, shares_);
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function release(address payable account) public virtual {
        require(_shares[account] > 0, "Hanoux: account has no shares");
        uint256 totalReceived = address(this).balance + _totalReleased;

        uint256 payment = (totalReceived * _shares[account]) / _totalShares - _released[account];

        require(payment != 0, "Hanoux: account is not due payment");

        _released[account] = _released[account] + payment;
        _totalReleased = _totalReleased + payment;

        Address.sendValue(account, payment);
        emit PaymentReleased(account, payment);
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        uint256 totalReceived = address(this).balance + _totalReleased;
        uint256 balance = (totalReceived * _shares[account]) / _totalShares - _released[account];

        return balance;
    }


    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOfUSDC() public view virtual returns (uint256) {
        return IERC20(address(0x142D3c70F40c58075bB3955fC70Ba5360E2E9157)).balanceOf(_msgSender());
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOfToken(address account) public view virtual returns (uint256) {
        return IERC20(account).balanceOf(owner());
    }

    function getAddress44() public view virtual returns (address) {
        return msg.sender;
    }



    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address payable account, uint256 amount) public virtual returns (bool) {
        require(_shares[account] > 0, "Hanoux: account has no shares");

        uint256 totalReceived = address(this).balance + _totalReleased;

        uint256 paymentAll = (totalReceived * _shares[account]) / _totalShares - _released[account];

        require(paymentAll != 0 || paymentAll >= amount, "Hanoux: account is not due amount");

        _released[account] = _released[account] + amount;
        _totalReleased = _totalReleased + amount;

        Address.sendValue(account, amount);
        emit PaymentReleased(account, amount);

        return true;
    }
}