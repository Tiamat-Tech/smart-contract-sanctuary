// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libraries/BaseERC20Token.sol";
import "./libraries/Authorizable.sol";

contract JoyToken is ERC20, Ownable, Authorizable {
// contract JoyToken is BaseERC20Token, Authorizable {
    using SafeMath for uint256;

    uint256 private _cap;
    uint256 private _totalLock;
    uint256 public lockFromBlock;
    uint256 public lockToBlock;
    uint256 public manualMintLimit;
    uint256 public manualMinted = 0;
    address public miner;

    mapping(address => uint256) private _locks;
    mapping(address => uint256) private _lastUnlockBlock;

    // Max transfer amount rate in basis points. Default is 100% of total
    // supply, and it can't be less than 0.5% of the supply.
    uint16 public maxTransferAmountRate = 10000;

    // Addresses that are excluded from anti-whale checking.
    mapping(address => bool) private _excludedFromAntiWhale;

    // Events.
    event MaxTransferAmountRateUpdated(uint256 previousRate, uint256 newRate);
    event Lock(address indexed to, uint256 value);
    event Unlock(address indexed to, uint256 value);

    // Modifiers.

    /**
     * @dev Ensures that the anti-whale rules are enforced.
     */
    modifier antiWhale(address sender, address recipient, uint256 amount) {
        if (maxTransferAmount() > 0) {
            if (
                _excludedFromAntiWhale[sender] == false
                && _excludedFromAntiWhale[recipient] == false
            ) {
                require(amount <= maxTransferAmount(), "antiWhale: Transfer amount exceeds the maxTransferAmount");
            }
        }
        _;
    }

    // BaseERC20Token("Joy Token", "$JOY", 18, 5000_000e18)
    constructor(
      string memory _name,
      string memory _symbol
    ) ERC20(_name, _symbol) {
        uint256 initialSupply_ = 1000_000e18;
        manualMintLimit = 1000_000e18;
        _cap = 5000_000e18;
        lockFromBlock = 0;
        lockToBlock = 0;

        _excludedFromAntiWhale[msg.sender] = true;
        _excludedFromAntiWhale[address(0)] = true;
        _excludedFromAntiWhale[address(this)] = true;
        
        _mint(_msgSender(), initialSupply_);
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    /**
     * @dev Updates the total cap.
     */
    function capUpdate(uint256 _newCap) public onlyAuthorized {
        _cap = _newCap;
    }

    // Update the lockFromBlock
    function lockFromUpdate(uint256 _newLockFrom) public onlyAuthorized {
        lockFromBlock = _newLockFrom;
    }

    // Update the lockToBlock
    function lockToUpdate(uint256 _newLockTo) public onlyAuthorized {
        lockToBlock = _newLockTo;
    }

    function unlockedSupply() public view returns (uint256) {
        return totalSupply().sub(_totalLock);
    }

    function lockedSupply() public view returns (uint256) {
        return totalLock();
    }

    function circulatingSupply() public view returns (uint256) {
        return totalSupply();
    }

    function totalLock() public view returns (uint256) {
        return _totalLock;
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - minted tokens must not cause the total supply to go over the cap.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) {
            // When minting tokens
            require(
                totalSupply().add(amount) <= _cap,
                "ERC20Capped: cap exceeded"
            );
        }
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override
    antiWhale(sender, recipient, amount)
    {
        super._transfer(sender, recipient, amount);
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterGardener).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function manualMint(address _to, uint256 _amount) public onlyAuthorized {
        require(manualMinted < manualMintLimit, "ERC20: manualMinted greater than manualMintLimit");
        _mint(_to, _amount);
        manualMinted = manualMinted.add(_amount);
    }

    function totalBalanceOf(address _holder) public view returns (uint256) {
        return _locks[_holder].add(balanceOf(_holder));
    }

    function lockOf(address _holder) public view returns (uint256) {
        return _locks[_holder];
    }

    function lastUnlockBlock(address _holder) public view returns (uint256) {
        return _lastUnlockBlock[_holder];
    }

    function lock(address _holder, uint256 _amount) public onlyAuthorized {
        require(_holder != address(0), "Cannot lock to the zero address");
        require(
            _amount <= balanceOf(_holder),
            "Lock amount over balance"
        );

        _transfer(_holder, address(this), _amount);

        _locks[_holder] = _locks[_holder].add(_amount);
        _totalLock = _totalLock.add(_amount);
        if (_lastUnlockBlock[_holder] < lockFromBlock) {
            _lastUnlockBlock[_holder] = lockFromBlock;
        }
        emit Lock(_holder, _amount);
    }

    function canUnlockAmount(address _holder) public view returns (uint256) {
        if (block.number < lockFromBlock) {
            return 0;
        } else if (block.number >= lockToBlock) {
            return _locks[_holder];
        } else {
            uint256 releaseBlock = block.number.sub(_lastUnlockBlock[_holder]);
            uint256 numberLockBlock =
                lockToBlock.sub(_lastUnlockBlock[_holder]);
            return _locks[_holder].mul(releaseBlock).div(numberLockBlock);
        }
    }

    // Unlocks some locked tokens immediately.
    function unlockForUser(address account, uint256 amount) public onlyAuthorized {
        // First we need to unlock all tokens the address is eligible for.
        uint256 pendingLocked = canUnlockAmount(account);
        if (pendingLocked > 0) {
            _unlock(account, pendingLocked);
        }

        // Now that that's done, we can unlock the extra amount passed in.
        _unlock(account, amount);
    }

    function unlock() public {
        uint256 amount = canUnlockAmount(msg.sender);
        _unlock(msg.sender, amount);
    }

    function _unlock(address holder, uint256 amount) internal {
        require(_locks[holder] > 0, "Insufficient locked tokens");

        // Make sure they aren't trying to unlock more than they have locked.
        if (amount > _locks[holder]) {
            amount = _locks[holder];
        }

        // If the amount is greater than the total balance, set it to max.
        if (amount > balanceOf(address(this))) {
            amount = balanceOf(address(this));
        }
        _transfer(address(this), holder, amount);
        _locks[holder] = _locks[holder].sub(amount);
        _lastUnlockBlock[holder] = block.number;
        _totalLock = _totalLock.sub(amount);

        emit Unlock(holder, amount);
    }

    // This function is for dev address migrate all balance to a multi sig address
    function transferAll(address _to) public {
        _locks[_to] = _locks[_to].add(_locks[msg.sender]);

        if (_lastUnlockBlock[_to] < lockFromBlock) {
            _lastUnlockBlock[_to] = lockFromBlock;
        }

        if (_lastUnlockBlock[_to] < _lastUnlockBlock[msg.sender]) {
            _lastUnlockBlock[_to] = _lastUnlockBlock[msg.sender];
        }

        _locks[msg.sender] = 0;
        _lastUnlockBlock[msg.sender] = 0;

        _transfer(msg.sender, _to, balanceOf(msg.sender));
    }

    /**
     * @dev Update the max transfer amount rate.
     */
    function updateMaxTransferAmountRate(uint16 _maxTransferAmountRate) public onlyAuthorized {
        require(_maxTransferAmountRate <= 10000, "updateMaxTransferAmountRate: Max transfer amount rate must not exceed the maximum rate.");
        require(_maxTransferAmountRate >= 50, "updateMaxTransferAmountRate: Max transfer amount rate must be more than 0.005.");
        emit MaxTransferAmountRateUpdated(maxTransferAmountRate, _maxTransferAmountRate);
        maxTransferAmountRate = _maxTransferAmountRate;
    }

    /**
     * @dev Calculates the max transfer amount.
     */
    function maxTransferAmount() public view returns (uint256) {
        return totalSupply().mul(maxTransferAmountRate).div(10000);
    }

    /**
     * @dev Sets an address as excluded or not from the anti-whale checking.
     */
    function setExcludedFromAntiWhale(address _account, bool _excluded) public onlyAuthorized {
        _excludedFromAntiWhale[_account] = _excluded;
    }
}