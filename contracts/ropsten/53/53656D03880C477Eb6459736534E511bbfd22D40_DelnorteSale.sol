pragma solidity ^0.6.0;

import "./math/SafeMath.sol";
import "./access/roles/ManagerRole.sol";
import "./token/Detailed.sol";
import "./DTV.sol";
import "./utils/ReentrancyGuard.sol";
import "./utils/PausableCrowdsale.sol";

contract DelnorteSale is PausableCrowdsale, ManagerRole {
    using SafeMath for uint256;
    mapping(address => uint256) private _wagers;
    event TokensReleased(address beneficiary, uint256 amount);
    event TokensWithdrawn(address beneficiary, uint256 amount);
    event TokensTransfered(address beneficiary, uint256 amount);
    event VestingToggled(bool vested);

    struct TimelockData {
        uint256 time;
        uint256[2] rates;
    }

    struct StageData {
        uint256 supply;
        uint256 cap;
        uint256 rate;
        mapping (address => uint256) balances;
        mapping (address => uint256) released;
    }

    mapping (address => uint256) private _times;
    TimelockData[] private _calendar;
    StageData[] private _stages;
    uint256 private _currentStage = 0;
    bool private _vested = true;

    constructor(address payable wallet, IERC20 token) public Crowdsale(wallet, token) {
        _stages.push(StageData({
        supply: 0,
        cap: 2500000 * (10 ** 18),
        rate: 9520000000000
        }));

        _stages.push(StageData({
        supply: 0,
        cap: 3333333 * (10 ** 18),
        rate: 14290000000000
        }));

        _stages.push(StageData({
        supply: 0,
        cap: 1666667 * (10 ** 18),
        rate: 21430000000000
        }));

        _calendar.push(TimelockData({ time: uint256(1637180199), rates: [uint256(30), 30] }));
        _calendar.push(TimelockData({ time: uint256(1637183799), rates: [uint256(70), 70] }));

    }

    function name() public view virtual returns (string memory) {
        return ERC20Detailed(address(token())).name();
    }

    function symbol() public view virtual returns (string memory) {
        return ERC20Detailed(address(token())).symbol();
    }

    function decimals() public view virtual returns (uint8) {
        return ERC20Detailed(address(token())).decimals();
    }

    function timestamp() public view virtual returns (uint256) {
        return block.timestamp;
    }

    function vested() public view virtual returns (bool) {
        return _vested;
    }

    function timeOf(address owner) public view virtual returns (uint256) {
        return _times[owner];
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        uint256 balance = 0;
        for (uint256 i = 0; i < _stages.length; i++) {
        balance = balance.add(_stages[i].balances[owner]);
        }
        return balance;
    }

    function releasedOf(address owner) public view virtual returns (uint256) {
        uint256 release = 0;
        for (uint256 i = 0; i < _stages.length; i++) {
        release = release.add(_stages[i].released[owner]);
        }
        return release;
    }

    function balanceOfStage(uint256 id, address owner) public view virtual returns (uint256) {
        return _stages[id].balances[owner];
    }

    function releasedOfStage(uint256 id, address owner) public view virtual returns (uint256) {
        return _stages[id].released[owner];
    }

    function getCalendarLength() public view virtual returns (uint256) {
        return _calendar.length;
    }

    function getCalendar(uint256 id) public view virtual returns (uint256, uint256[2] memory) {
        TimelockData memory timelock = _calendar[id];
        return (timelock.time, timelock.rates);
    }

    function getStage(uint256 id) public view virtual returns (uint256, uint256, uint256) {
        StageData memory stage = _stages[id];
        return (stage.supply, stage.cap, stage.rate);
    }

    function getCurrentStage() public view virtual returns (uint256) {
        return _currentStage;
    }

    function setCurrentStage(uint256 stage) public virtual onlyManager returns (bool) {
        require(stage < _stages.length, "DelnorteCrowdsale: new stage is greater than stages count");
        _currentStage = stage;
        return true;
    }

    function toggleVesting(bool value) public virtual onlyManager {
        _vested = value;
        emit VestingToggled(value);
    }
 
    function transferTokens(address to, uint256 value) public virtual onlyManager returns (bool) {
        uint256 totalSupply = 0;
        for (uint256 i = 0; i < _stages.length; i++) {
        totalSupply = totalSupply.add(_stages[i].supply);
        }

        uint256 balance = token().balanceOf(address(this));

        require(to != address(0), "DelnorteCrowdsale: transfer to the zero address");
        require(balance.sub(value) >= totalSupply, "DelnorteCrowdsale: transfer to much tokens");

        emit TokensTransfered(to, value);

        return token().transfer(to, value);
    }

    function releasableAmount(address beneficiary) public view virtual returns (uint256) {
        TimelockData memory timelock;
        uint256[2] memory rates = [uint256(0),  0];
        for (uint256 i = 0; i < _calendar.length; i++) {
            timelock = _calendar[i];
            if (block.timestamp > timelock.time) {
            if (timelock.time > _times[beneficiary]) {
                rates[0] = rates[0].add(timelock.rates[0]);
                rates[1] = rates[1].add(timelock.rates[1]);
            }
            } else {
            break;
            }
        }

        uint256 amount = 0;
        uint256 available = 0;
        uint256 unreleased = 0;
        for (uint256 i = 0; i < _stages.length; i++) {
        unreleased = _stages[i].balances[beneficiary].sub(_stages[i].released[beneficiary]);
        if (rates[i] > 0 && unreleased > 0) {
            available = _stages[i].balances[beneficiary].mul(rates[i]).div(100);
            amount = amount.add(available);
        }
        }

        return amount;
    }

    function withdrawTokens(address beneficiary) public virtual {
        require(!_vested, "DelnorteCrowdsale: locked by vesting period");

        uint256 balance = balanceOf(beneficiary);
        uint256 released = releasedOf(beneficiary);

        uint256 amount = balance.sub(released);

        require(amount > 0, "DelnorteCrowdsale: beneficiary is not due any tokens");

        for (uint256 i = 0; i < _stages.length; i++) {
        _stages[i].released[beneficiary] = _stages[i].balances[beneficiary];
        }

        _deliverTokens(beneficiary, amount);

        emit TokensWithdrawn(beneficiary, amount);
    }

    function releaseTokens(address beneficiary) public virtual {
        TimelockData memory timelock;
        uint256[2] memory rates = [uint256(0),  0];
        for (uint256 i = 0; i < _calendar.length; i++) {
            timelock = _calendar[i];
            if (block.timestamp >= timelock.time) {
            if (timelock.time > _times[beneficiary]) {
                rates[0] = rates[0].add(timelock.rates[0]);
                rates[1] = rates[1].add(timelock.rates[1]);
            }
            } else {
            break;
            }
        }

        uint256 amount = 0;
        uint256 available = 0;
        uint256 unreleased = 0;
        for (uint256 i = 0; i < _stages.length; i++) {
        unreleased = _stages[i].balances[beneficiary].sub(_stages[i].released[beneficiary]);
        if (rates[i] > 0 && unreleased > 0) {
            available = _stages[i].balances[beneficiary].mul(rates[i]).div(100);
            _stages[i].released[beneficiary] = _stages[i].released[beneficiary].add(available);
            amount = amount.add(available);

            require(_stages[i].released[beneficiary] <= _stages[i].balances[beneficiary], "DelnorteCrowdsale: purchase amount exceeded");
        }
        }

        require(amount > 0, "DelnorteCrowdsale: beneficiary is not due any tokens");

        _times[beneficiary] = block.timestamp;
        _deliverTokens(beneficiary, amount);

        emit TokensReleased(beneficiary, amount);
    }

    function _processPurchase(address beneficiary, uint256 tokenAmount) internal virtual override(Crowdsale) {
        StageData storage stage = _stages[_currentStage];

        require(stage.supply.add(tokenAmount) <= stage.cap, "DelnorteCrowdsale: stage cap exceeded");

        stage.supply = stage.supply.add(tokenAmount);

        mapping(address => uint256) storage balances = stage.balances;
        balances[beneficiary] = balances[beneficiary].add(tokenAmount);
    }

 
    function addStage(uint256 supply, uint256 cap, uint256 rate) public virtual onlyManager returns (bool) {
        require(cap > 0, 'DelnorteSwap: Cap must be greater than zero');
        require(rate > 0, 'DelnorteSwap: Rate must be greater than zero');
        
        _stages.push(StageData({
            supply: supply,
            cap: cap,
            rate: rate
        }));
        
        return true;
    }
    
    function addCalendar(uint256 time, uint256 ratesFirst, uint256 ratesSecond) public virtual onlyManager returns (bool) {
        require(time > 0, 'DelnorteSwap: Time must be greater than zero');

        _calendar.push(TimelockData({
            time: time,
            rates: [ratesFirst, ratesSecond]
        }));
        return true;
    }

    
    function changeStage(uint8 id, uint256 supply, uint256 cap, uint256 rate) public virtual onlyManager returns (bool) {
        _stages[id].supply = supply;
        _stages[id].cap = cap;
        _stages[id].rate = rate;
        return true;
    }
    
   
    function changeCalendar(uint8 id, uint256 time, uint256 rateFirst, uint256 rateSecond) public virtual onlyManager returns (bool) {
        _calendar[id].time = time;
        _calendar[id].rates[0] = rateFirst;
        _calendar[id].rates[1] = rateSecond;
        
        return true;
    }

    function pause() public virtual onlyManager whenNotPaused returns (bool) {
        Pausable._pause();
        return true;
    }

    
    function unpause() public virtual onlyManager whenPaused returns (bool) {
        Pausable._unpause();
        return true;
    }
}