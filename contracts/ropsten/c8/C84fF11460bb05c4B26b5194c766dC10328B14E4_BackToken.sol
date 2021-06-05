//SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.4;

import '@openzeppelin/contracts/utils/Context.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../claimer/IClaimer.sol';

    struct Referrer {
        address account;
        uint256 startOfReferral;
    }

contract BackToken is IERC20, AccessControl {
    // Roles
    bytes32 public constant REFERRAL_MANAGER_ROLE = keccak256("REFERRAL_MANAGER_ROLE");

    // ERC20 structures
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    // Fees
    mapping (address => bool) private _excludedFromSendingFees;
    mapping (address => bool) private _excludedFromReceivingFees;
    uint256 private _claimerFeePercentage = 9;
    uint256 private _fundingFeePercentage = 1; // Funding fee percentage is also used to calculate referral fee percentage

    // Referral
    mapping (address => Referrer) private _referrers;
    uint256 private _minReferralBalance = 10 ether;
    uint256 private _referralTimeWindow = 3 * 30 days;

    IClaimer private _claimer; // Claimer contract can be null
    address private _fundingAddress;

    uint256 private constant TOTAL_SUPPLY = 500000000 ether; // 500'000'000 BACKs

    // ERC20 definitions
    string private _name = "BACK";
    string private _symbol = "BACK";
    uint8 private _decimals = 18;

    event ClaimerAddressChanged(address indexed newClaimer);
    event FundingAddressChanged(address indexed newFunding);
    event ReferrerSet(address indexed referrer, address indexed to, uint256 when);
    event ReferralTimeWindowChanged(uint256 newTimeWindow);
    event MinReferralBalanceChanged(uint256 newMinReferralBalance);
    event ClaimerFeePercentageChanged(uint256 newClaimerFeePercentage);
    event FundingFeePercentageChanged(uint256 newFundingFeePercentage);
    event AddressExcludedFromSendingFees(address indexed account, bool excluded);
    event AddressExcludedFromReceivingFees(address indexed account, bool excluded);

    constructor(address initialFundingAddress, address claimerAddress) {
        require(initialFundingAddress != address(0), "BackToken: funding address is the zero address");
        require(claimerAddress != address(0), "BackToken: claimer address is the zero address");

        // Give initial balance to contract creator
        _balances[_msgSender()] = TOTAL_SUPPLY;

        // Exclude the contract itself from fees
        _excludedFromSendingFees[address(this)] = true;
        _excludedFromReceivingFees[address(this)] = true;

        // Exclude the claimer and funding address from fees
        _excludedFromSendingFees[initialFundingAddress] = true;
        _excludedFromReceivingFees[initialFundingAddress] = true;
        _excludedFromSendingFees[claimerAddress] = true;
        _excludedFromReceivingFees[claimerAddress] = true;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(REFERRAL_MANAGER_ROLE, _msgSender());

        _claimer = IClaimer(claimerAddress);
        _fundingAddress = initialFundingAddress;

        emit Transfer(address(0), _msgSender(), TOTAL_SUPPLY);
        emit ClaimerAddressChanged(claimerAddress);
    }

    modifier onlyAdmins() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "BackToken: address is not an admin");
        _;
    }

    modifier onlyReferralManagers() {
        require(hasRole(REFERRAL_MANAGER_ROLE, _msgSender()), "BackToken: address is not a referral manager");
        _;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function balanceOf(address account) override external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() override external pure returns (uint256) {
        return TOTAL_SUPPLY;
    }

    function claimer() external view returns (IClaimer) {
        return _claimer;
    }

    function claimerFeePercentage() external view returns (uint256) {
        return _claimerFeePercentage;
    }

    function fundingFeePercentage() external view returns (uint256) {
        return _fundingFeePercentage;
    }

    function fundingAddress() external view returns (address) {
        return _fundingAddress;
    }

    function isExcludedFromSendingFees(address account) external view returns (bool) {
        return _excludedFromSendingFees[account];
    }

    function isExcludedFromReceivingFees(address account) external view returns (bool) {
        return _excludedFromReceivingFees[account];
    }

    function referralTimeWindow() external view returns (uint256) {
        return _referralTimeWindow;
    }

    function minReferralBalance() external view returns (uint256) {
        return _minReferralBalance;
    }

    function referrer(address account) external view returns (Referrer memory) {
        return _referrers[account];
    }

    function updateClaimer(address newClaimerAddress) external onlyAdmins {
        _excludedFromSendingFees[address(_claimer)] = false;
        _excludedFromReceivingFees[address(_claimer)] = false;
        _claimer = IClaimer(newClaimerAddress);

        if (newClaimerAddress != address(0)) {
            _excludedFromSendingFees[newClaimerAddress] = true;
            _excludedFromReceivingFees[newClaimerAddress] = true;
        }

        emit ClaimerAddressChanged(newClaimerAddress);
    }

    function updateFunding(address newFundingAddress) external onlyAdmins {
        _excludedFromSendingFees[_fundingAddress] = false;
        _excludedFromReceivingFees[_fundingAddress] = false;
        _fundingAddress = newFundingAddress;

        if (newFundingAddress != address(0)) {
            _excludedFromSendingFees[newFundingAddress] = true;
            _excludedFromReceivingFees[newFundingAddress] = true;
        }

        emit FundingAddressChanged(newFundingAddress);
    }

    function updateReferralTimeWindow(uint256 newReferralTimeWindow) external onlyReferralManagers {
        _referralTimeWindow = newReferralTimeWindow;
        emit ReferralTimeWindowChanged(newReferralTimeWindow);
    }

    function updateMinReferralBalance(uint256 newMinReferralBalance) external onlyReferralManagers {
        _minReferralBalance = newMinReferralBalance;
        emit MinReferralBalanceChanged(newMinReferralBalance);
    }

    function updateClaimerFeePercentage(uint256 newClaimerFeePercentage) external onlyAdmins {
        _claimerFeePercentage = newClaimerFeePercentage;
        emit ClaimerFeePercentageChanged(newClaimerFeePercentage);
    }

    function updateFundingFeePercentage(uint256 newFundingFeePercentage) external onlyAdmins {
        _fundingFeePercentage = newFundingFeePercentage;
        emit FundingFeePercentageChanged(newFundingFeePercentage);
    }

    function excludeAddressFromSendingFees(address account) external onlyAdmins {
        _excludeAddressFromSendingFees(account, true);
    }

    function setExcludeAddressFromSendingFees(address account, bool excluded) external onlyAdmins {
        _excludeAddressFromSendingFees(account, excluded);
    }

    function excludeAddressFromReceivingFees(address account) external onlyAdmins {
        _excludeAddressFromReceivingFees(account, true);
    }

    function setExcludeAddressFromReceivingFees(address account, bool excluded) external onlyAdmins {
        _excludeAddressFromReceivingFees(account, excluded);
    }

    function transfer(address recipient, uint256 amount) override external returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferWithReferrer(address recipient, address _referrer, uint256 amount) external returns (bool) {
        _setReferrer(_referrer, _msgSender());
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) override external returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 newAllowance = _allowances[sender][_msgSender()] - amount;
        _approve(sender, _msgSender(), newAllowance);
        return true;
    }

    function allowance(address owner, address spender) override public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) override public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function setReferrer(address _referrer, address to) external onlyReferralManagers returns (bool) {
        _setReferrer(_referrer, to);
        return true;
    }

    function unsetReferrer(address to) external onlyReferralManagers returns (bool) {
        _unsetReferrer(to);
        return true;
    }

    function _setReferrer(address _referrer, address to) private {
        require(_referrer != address(0), "BackToken: referrer is the zero address");
        require(_referrers[to].account == address(0), "BackToken: referrer already set");
        require(to != address(0), "BackToken: referree is the zero address");

        Referrer memory ref;
        ref.account = _referrer;
        ref.startOfReferral = block.timestamp;

        _referrers[to] = ref;

        emit ReferrerSet(_referrer, to, block.timestamp);
    }

    function _unsetReferrer(address to) private {
        require(to != address(0), "BackToken: referree is the zero address");

        Referrer memory ref;
        ref.account = address(0);
        ref.startOfReferral = 0;

        _referrers[to] = ref;

        emit ReferrerSet(address(0), to, 0);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 actualAmount = amount;

        if (!_excludedFromSendingFees[from] && !_excludedFromReceivingFees[to]) {
            actualAmount = actualAmount - _applyClaimerFees(from, amount);

            uint256 stackedBalance = _isContract(address(_claimer))
            ? _claimer.balanceOf(_referrers[from].account)
            : 0;

            if (
                _referrers[from].account != address(0) &&
                _referrers[from].startOfReferral + _referralTimeWindow >= block.timestamp &&
                _balances[_referrers[from].account] + stackedBalance >= _minReferralBalance
            ) {
                actualAmount = actualAmount - _applyReferralFees(from, amount);
            } else {
                actualAmount = actualAmount - _applyFundingFees(from, amount);
            }
        }

        _balances[from] = _balances[from] - actualAmount;
        _balances[to] = _balances[to] + actualAmount;

        emit Transfer(from, to, actualAmount);
    }

    function _applyClaimerFees(address from, uint256 amount) private returns (uint256) {
        uint256 claimerFees = _calculateFee(amount, _claimerFeePercentage);

        address claimerAddr = address(_claimer);
        _balances[claimerAddr] = _balances[claimerAddr] + claimerFees;

        emit Transfer(from, claimerAddr, claimerFees);

        return claimerFees;
    }

    function _applyFundingFees(address from, uint256 amount) private returns (uint256) {
        uint256 fundingFees = _calculateFee(amount, _fundingFeePercentage);

        _balances[_fundingAddress] = _balances[_fundingAddress] + fundingFees;
        emit Transfer(from, _fundingAddress, fundingFees);

        return fundingFees;
    }

    function _applyReferralFees(address from, uint256 amount) private returns (uint256) {
        uint256 fundingFees = _calculateFee(amount, _fundingFeePercentage);

        _balances[_referrers[from].account] = _balances[_referrers[from].account] + fundingFees;
        emit Transfer(from, _referrers[from].account, fundingFees);

        return fundingFees;
    }

    function _calculateFee(uint256 amount, uint256 feePercentage) private pure returns (uint256) {
        return amount * feePercentage / 100;
    }

    function _excludeAddressFromSendingFees(address account, bool excluded) private {
        require(account != address(0), "BackToken: excluding the zero address");

        _excludedFromSendingFees[account] = excluded;
        emit AddressExcludedFromSendingFees(account, excluded);
    }

    function _excludeAddressFromReceivingFees(address account, bool excluded) private {
        require(account != address(0), "BackToken: excluding the zero address");

        _excludedFromReceivingFees[account] = excluded;
        emit AddressExcludedFromReceivingFees(account, excluded);(account, excluded);
    }

    function _isContract(address addr) private view returns (bool) {
        if (addr == address(0)) return false;

        uint32 size;
        assembly {
            size := extcodesize(addr)
        }

        return size > 0;
    }
}