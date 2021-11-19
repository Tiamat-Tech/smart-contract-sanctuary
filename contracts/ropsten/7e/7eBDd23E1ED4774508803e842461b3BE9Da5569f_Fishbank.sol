// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Fishbank is Ownable {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    event DepositAccepted(
        address _app,
        uint256 _amount,
        uint256 _reward,
        uint256 _main
    );

    event Withdrawal(address _app, address _maintainer, uint256 _amount);
    event ApplicationRegistered(address _app, address _maintainer);
    event RateAdjusted(uint16 _oldRate, uint16 _newRate);
    event MaintainerChanged(address _maintainer);

    uint16 private constant MAX_RATE = 1000;
    uint16 rate = 500;
    address public currency;
    address sinkAddress;
    mapping(address => uint256) balances; // app-> balance
    mapping(address => address) maintainers; // app -> maintainers
    mapping(address => bool) registrations;

    bool private emergency;

    modifier stopInEmergency() {
        require(!emergency);
        _;
    }

    modifier onlyInEmergency() {
        require(emergency);
        _;
    }

    constructor(address _sinkAddress, address _currency) {
        sinkAddress = _sinkAddress;
        currency = _currency;
    }

    function toggleEmergency() public onlyOwner returns (bool) {
        emergency = !emergency;
        return true;
    }

    function setRate(uint16 _rate) public onlyOwner {
        require(_rate < MAX_RATE, "Rate must be less than 10%");
        uint16 _oldRate = rate;
        rate = _rate;

        emit RateAdjusted(_oldRate, _rate);
    }

    // Depositors call this to register their application
    function registerMaintainer(address _maintainer) public stopInEmergency {
        address _app = msg.sender;
        require(_app != _maintainer, "App cannot be controller");
        require(_app != owner(), "App cannot be owner");
        require(_app != address(0), "App cannot be null address");
        require(_maintainer != address(0), "App cannot be null address");
        maintainers[_app] = _maintainer;
        registrations[_app] = true;

        emit ApplicationRegistered(_app, _maintainer);
    }

    function blockMaintainer(address _app) public onlyOwner {
        require(_app != address(0));
        maintainers[_app] = address(0);
    }

    function withdrawEmergency(address _app, address _sender)
        public
        onlyOwner
        onlyInEmergency
    {
        _withdrawAccount(_app, _sender);
    }

    // Owner calls this to change mainatainer of an app
    function setMaintainer(address _app, address _maintainer) public onlyOwner {
        require(_app != address(0));
        maintainers[_app] = _maintainer;

        emit MaintainerChanged(_maintainer);
    }

    function calculateSplit(uint256 _amount)
        internal
        view
        returns (uint256, uint256)
    {
        return ((_amount * rate) / 10000, (_amount * (10000 - rate)) / 10000);
    }

    function balanceOf(address _app) public view returns (uint256) {
        return balances[_app];
    }

    function maintainerOf(address _app) public view returns (address) {
        return maintainers[_app];
    }

    function deposit(uint256 _amount) public stopInEmergency {
        address _app = msg.sender;
        require(_amount > 0, "Amount must be greater than 0");
        require(_app != sinkAddress, "multisig cannot be a depositor");
        require(registrations[_app], "App is not registered");
        require(
            IERC20(currency).allowance(address(_app), address(this)) >= _amount,
            "Please ensure token allowance has been set to be greater than the amount"
        );

        (uint256 _reward, uint256 _main) = calculateSplit(_amount);

        balances[sinkAddress] += _main;
        balances[_app] += _reward;

        IERC20(currency).safeTransferFrom(_app, address(this), _amount);

        emit DepositAccepted(_app, _amount, _main, _reward);
    }

    function doWithdrawToSink() public onlyOwner stopInEmergency {
        _withdrawAccount(sinkAddress, sinkAddress);
    }

    function _withdrawAccount(address _app, address _to) internal {
        uint256 _amount = balances[_app];

        require(_app != address(0), "App cannot be null address");
        require(_to != address(0), "Maintainer cannot be null address");
        require(_amount > 0, "No balance available to withdraw");

        balances[_app] = 0;

        IERC20(currency).safeTransfer(_to, _amount);

        emit Withdrawal(_app, _to, _amount);
    }

    function doWithdraw(address _app) public stopInEmergency {
        require(registrations[_app], "App is not registered");
        require(maintainers[_app] != address(0), "Maintainer is blocked");

        _withdrawAccount(_app, msg.sender);
    }
}