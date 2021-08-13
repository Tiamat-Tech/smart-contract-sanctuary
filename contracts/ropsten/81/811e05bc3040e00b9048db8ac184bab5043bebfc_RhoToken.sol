//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "../interfaces/IRhoTokenRewards.sol";
import "../interfaces/IRhoToken.sol";

contract RhoToken is IRhoToken, ERC20Upgradeable, AccessControlEnumerableUpgradeable {
    using AddressUpgradeable for address;

    /**
     * @dev internally stored without any multiplier
     */
    mapping(address => uint256) private _balances;

    /**
     * @dev rebase option will be set when user calls setRebasingOption()
     * default is UNKNOWN, determined by EOA/contract type
     */
    enum RebaseOption {UNKNOWN, REBASING, NON_REBASING}

    /**
     * @dev this mapping is valid only for addresses that have already changed their options.
     * To query an account's rebase option, call `isRebasingAccount()` externally
     * or `isRebasingAccountInternal()` internally.
     */
    mapping(address => RebaseOption) private _rebaseOptions;

    uint256 private _rebasingTotalSupply;
    uint256 private _nonRebasingTotalSupply;

    uint256 private constant ONE = 1e36;
    uint256 private multiplier;
    address public tokenRewardsAddress;
    uint256 public lastUpdateTime;

    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function __initialize(string memory name_, string memory symbol_) public initializer {
        ERC20Upgradeable.__ERC20_init(name_, symbol_);
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        _setMultiplier(ONE);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function totalSupply() public view override(ERC20Upgradeable, IERC20Upgradeable) returns (uint256) {
        return _timesMultiplier(_rebasingTotalSupply) + _nonRebasingTotalSupply;
    }

    function adjustedRebasingSupply() external view override returns (uint256) {
        return _timesMultiplier(_rebasingTotalSupply);
    }

    function unadjustedRebasingSupply() external view override returns (uint256) {
        return _rebasingTotalSupply;
    }

    function nonRebasingSupply() external view override returns (uint256) {
        return _nonRebasingTotalSupply;
    }

    function balanceOf(address account) public view override(ERC20Upgradeable, IERC20Upgradeable) returns (uint256) {
        if (isRebasingAccountInternal(account)) {
            return _timesMultiplier(_balances[account]);
        }
        return _balances[account];
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override updateTokenRewards(sender) updateTokenRewards(recipient) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(sender, recipient, amount);
        // deducting from sender
        uint256 amountToDeduct = amount;
        if (isRebasingAccountInternal(sender)) {
            amountToDeduct = _dividedByMultiplier(amount);
            require(_balances[sender] >= amountToDeduct, "ERC20: transfer amount exceeds balance");
            _rebasingTotalSupply -= amountToDeduct;
        } else {
            require(_balances[sender] >= amountToDeduct, "ERC20: transfer amount exceeds balance");
            _nonRebasingTotalSupply -= amountToDeduct;
        }
        _balances[sender] -= amountToDeduct;
        // adding to recipient
        uint256 amountToAdd = amount;
        if (isRebasingAccountInternal(recipient)) {
            amountToAdd = _dividedByMultiplier(amount);
            _rebasingTotalSupply += amountToAdd;
        } else {
            _nonRebasingTotalSupply += amountToAdd;
        }
        _balances[recipient] += amountToAdd;
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal override updateTokenRewards(account) {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);
        uint256 amountToAdd = amount;
        if (isRebasingAccountInternal(account)) {
            amountToAdd = _dividedByMultiplier(amount);
            _rebasingTotalSupply += amountToAdd;
        } else {
            _nonRebasingTotalSupply += amountToAdd;
        }
        _balances[account] += amountToAdd;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal override updateTokenRewards(account) {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);
        uint256 amountToDeduct = amount;
        if (isRebasingAccountInternal(account)) {
            amountToDeduct = _dividedByMultiplier(amount);
            require(_balances[account] >= amountToDeduct, "ERC20: burn amount exceeds balance");
            _rebasingTotalSupply -= amountToDeduct;
        } else {
            require(_balances[account] >= amountToDeduct, "ERC20: burn amount exceeds balance");
            _nonRebasingTotalSupply -= amountToDeduct;
        }
        _balances[account] -= amountToDeduct;
        emit Transfer(account, address(0), amount);
    }

    /* multiplier */
    function setMultiplier(uint256 multiplier_) external override onlyRole(VAULT_ROLE) updateTokenRewards(address(0)) {
        _setMultiplier(multiplier_);
        emit MultiplierChange(multiplier_);
    }

    function _setMultiplier(uint256 multiplier_) internal {
        multiplier = multiplier_;
        lastUpdateTime = block.timestamp;
    }

    function getMultiplier() external view override returns (uint256 _multiplier, uint256 _lastUpdateTime) {
        _multiplier = multiplier;
        _lastUpdateTime = lastUpdateTime;
    }

    function mint(address account, uint256 amount) external override onlyRole(MINTER_ROLE) updateTokenRewards(account) {
        require(amount > 0, "amount must be greater than zero");
        return _mint(account, amount);
    }

    function burn(address account, uint256 amount) external override onlyRole(BURNER_ROLE) updateTokenRewards(account) {
        require(amount > 0, "amount must be greater than zero");
        return _burn(account, amount);
    }

    /* utils */
    function _timesMultiplier(uint256 input) internal view returns (uint256) {
        return (input * multiplier) / ONE;
    }

    function _dividedByMultiplier(uint256 input) internal view returns (uint256) {
        return (input * ONE) / multiplier;
    }

    function setRebasingOption(bool isRebasing) external override {
        if (isRebasingAccountInternal(_msgSender()) == isRebasing) {
            return;
        }
        uint256 userBalance = _balances[_msgSender()];
        if (isRebasing) {
            _rebaseOptions[_msgSender()] = RebaseOption.REBASING;
            _nonRebasingTotalSupply -= userBalance;
            _rebasingTotalSupply += _dividedByMultiplier(userBalance);
            _balances[_msgSender()] = _dividedByMultiplier(userBalance);
        } else {
            _rebaseOptions[_msgSender()] = RebaseOption.NON_REBASING;
            _rebasingTotalSupply -= userBalance;
            _nonRebasingTotalSupply += _timesMultiplier(userBalance);
            _balances[_msgSender()] = _timesMultiplier(userBalance);
        }
    }

    function isRebasingAccountInternal(address account) internal view returns (bool) {
        return
            (_rebaseOptions[account] == RebaseOption.REBASING) ||
            (_rebaseOptions[account] == RebaseOption.UNKNOWN && !account.isContract());
    }

    function isRebasingAccount(address account) external view override returns (bool) {
        return isRebasingAccountInternal(account);
    }

    /* token rewards */
    function setTokenRewards(address tokenRewards) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenRewardsAddress = tokenRewards;
    }

    // withdraw random token transfer into this contract
    function sweepERC20Token(address token, address to) external override onlyRole(SWEEPER_ROLE) {
        IERC20Upgradeable tokenToSweep = IERC20Upgradeable(token);
        tokenToSweep.transfer(to, tokenToSweep.balanceOf(address(this)));
    }

    /* ========== MODIFIERS ========== */
    modifier updateTokenRewards(address account) {
        if (tokenRewardsAddress != address(0)) {
            IRhoTokenRewards(tokenRewardsAddress).updateReward(account, address(this));
        }
        _;
    }
}