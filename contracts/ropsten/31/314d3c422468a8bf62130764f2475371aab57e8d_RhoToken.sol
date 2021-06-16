//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IRhoTokenRewards} from "../interfaces/IRhoTokenRewards.sol";

contract RhoToken is ERC20Upgradeable, OwnableUpgradeable {
    using AddressUpgradeable for address;

    mapping (address => uint256) private _eoaBalances;
    mapping (address => uint256) private _contractBalances;

    // mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _eoaTotalSupply;
    uint256 private _contractTotalSupply;

    string private _name;
    string private _symbol;

    uint256 private constant ONE = 1e36;

    uint256 private multiplier;

    address public tokenRewardsAddress;

    function __initialize(string memory name_, string memory symbol_) public initializer {
        ERC20Upgradeable.__ERC20_init(name_, symbol_);
        OwnableUpgradeable.__Ownable_init();
        _setMultiplier(ONE);
    }
    function totalSupply() public view virtual override returns (uint256) {
        return _timesMultiplier(rebasingSupply()) + nonRebasingSupply();
    }
    function rebasingSupply() public view virtual returns (uint256) {
        return _eoaTotalSupply;
    }
    function nonRebasingSupply() public view virtual returns (uint256) {
        return _contractTotalSupply;
    }
    function balanceOf(address account) public view virtual override returns (uint256) {
        if (account.isContract()){
            return _contractBalances[account];
        }
        return _timesMultiplier(_eoaBalances[account]);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override virtual updateTokenRewards(sender) updateTokenRewards(recipient) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);
        if (sender.isContract() && recipient.isContract()) {
            _transferC2C(sender, recipient, amount);
            return;
        }
        if (sender.isContract() && !recipient.isContract()) {
            _transferC2E(sender, recipient, amount);
            return;
        }
        if (!sender.isContract() && !recipient.isContract()) {
            _transferE2E(sender, recipient, amount);
            return;
        }
        _transferE2C(sender, recipient, amount);

    }

    function _transferE2E(address sender, address recipient, uint256 amount) internal virtual {
        uint256 senderBalance = _eoaBalances[sender];
        uint256 amountToDeduct = _dividedByMultiplier(amount);
        uint256 amountToAdd = amountToDeduct;
        require(senderBalance >= amountToDeduct, "ERC20: transfer amount exceeds balance");
        _eoaBalances[sender] = senderBalance - amountToDeduct;
        _eoaBalances[recipient] += amountToAdd;
        emit Transfer(sender, recipient, _timesMultiplier(amountToDeduct));

    }
    function _transferC2C(address sender, address recipient, uint256 amount) internal virtual {
        uint256 senderBalance = _contractBalances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _contractBalances[sender] = senderBalance - amount;
        _contractBalances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }
    function _transferE2C(address sender, address recipient, uint256 amount) internal virtual {
        uint256 amountToDeduct = _dividedByMultiplier(amount);
        uint256 amountToAdd = _timesMultiplier(amountToDeduct);
        require(_eoaBalances[sender] >= amountToDeduct, "ERC20: transfer amount exceeds balance");
        _eoaBalances[sender] -= amountToDeduct;
        _contractBalances[recipient] += amountToAdd;
        _eoaTotalSupply -= amountToDeduct;
        _contractTotalSupply += amountToAdd;
        emit Transfer(sender, recipient, amountToAdd);
    }
    function _transferC2E(address sender, address recipient, uint256 amount) internal virtual {
        uint256 amountToAdd = _dividedByMultiplier(amount);
        uint256 amountToDeduct = _timesMultiplier(amountToAdd);
        require(_contractBalances[sender] >= amountToDeduct, "ERC20: transfer amount exceeds balance");
        _contractBalances[sender] -= amountToDeduct;
        _eoaBalances[recipient] += amountToAdd;
        _contractTotalSupply -= amountToDeduct;
        _eoaTotalSupply += amountToAdd;
        emit Transfer(sender, recipient, amountToDeduct);
    }
    function _mint(address account, uint256 amount) internal virtual override updateTokenRewards(account) {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);
        if (account.isContract()) {
            _contractTotalSupply += amount;
            _contractBalances[account] += amount;
            emit Transfer(address(0), account, amount);
            return;
        }
        uint256 amountToAdd = _dividedByMultiplier(amount);
        _eoaTotalSupply += amountToAdd;
        _eoaBalances[account] += amountToAdd;
        emit Transfer(address(0), account, _timesMultiplier(amountToAdd));
    }
    function _burn(address account, uint256 amount) internal virtual override updateTokenRewards(account) {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);
        if (account.isContract()) {
            uint256 accountBalance = _contractBalances[account];
            require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
            _contractBalances[account] = accountBalance - amount;
            _contractTotalSupply -= amount;
            emit Transfer(account, address(0), amount);
            return;
        }
        uint256 amountToDeduct = _dividedByMultiplier(amount);
        uint256 __accountBalance = _eoaBalances[account];
        require(__accountBalance >= amountToDeduct, "ERC20: burn amount exceeds balance");
        _eoaBalances[account] = __accountBalance - amountToDeduct;
        _eoaTotalSupply -= amountToDeduct;
        emit Transfer(account, address(0), _timesMultiplier(amountToDeduct));
    }

    /* multiplier */
    event MultiplierChange(uint256 to);

    function setMultiplier(uint256 multiplier_) external onlyOwner updateTokenRewards(address(0)) {
        _setMultiplier(multiplier_);
        emit MultiplierChange(multiplier_);
    }
    function _setMultiplier(uint256 multiplier_) internal {
        multiplier = multiplier_;
    }
    function getMultiplier() external view returns(uint256) {
        return multiplier;
    }
    function mint(address account, uint256 amount) external virtual onlyOwner updateTokenRewards(account) {
        require(amount > 0, "amount must be greater than zero");
        return _mint(account, amount);
    }
    function burn(address account, uint256 amount) external virtual onlyOwner updateTokenRewards(account) {
        require(amount > 0, "amount must be greater than zero");
        return _burn(account, amount);
    }

    /* utils */
    /* think of a way to group this in a library */
    function _timesMultiplier(uint256 input) internal virtual view returns (uint256) {
        return input * multiplier / ONE;
    }
    function _dividedByMultiplier(uint256 input) internal virtual view returns (uint256) {
        return input * ONE / multiplier;
    }

    /* token rewards */
    function setTokenRewards(address tokenRewards) external onlyOwner {
        tokenRewardsAddress = tokenRewards;
    }

    // withdraw random token transfer into this contract
    function sweepERC20Token(address token, address to) external onlyOwner{
        IERC20Upgradeable tokenToSweep = IERC20Upgradeable(token);
        tokenToSweep.transfer(to, tokenToSweep.balanceOf(address(this)));
    }

    /* ========== MODIFIERS ========== */
    modifier updateTokenRewards(address account) {
        if (tokenRewardsAddress != address(0)) {
            IRhoTokenRewards(tokenRewardsAddress).updateReward(account);
        }
        _;
    }

}