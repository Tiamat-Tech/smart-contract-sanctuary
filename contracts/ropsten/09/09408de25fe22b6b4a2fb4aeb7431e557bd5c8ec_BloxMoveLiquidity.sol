// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "./interfaces/ILiquidity.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

// import "hardhat/console.sol";


contract BloxMoveLiquidity is ILiquidity, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    using SafeMathUpgradeable for uint;
    using SafeMathUpgradeable for uint112;
    using AddressUpgradeable for address;


    bytes4 private constant TRANSFER = bytes4(keccak256(bytes("transfer(address,uint256)")));
    bytes4 private constant TRANSFER_FROM = bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));
    bytes4 private constant BALANCE_OF = bytes4(keccak256(bytes("balanceOf(address)")));
    bytes4 private constant GET_RESERVES = bytes4(keccak256(bytes("getReserves()")));

    address public constant TOKEN = 0x0d98492eA6235156B320EdD90Cc9A9FDAca406E3;

    address public constant PAIR = 0xc66091C314a34e27B0Fe4Ee7473634ca823Ff029;

    address public treasury;

    uint private initialDay;

    uint private tokenReserve;
    uint private currencyReserve;

    uint public totalRewards;
    uint public totalLiquidity;

    struct LiquidityPosition {
        uint liquidityIn;
        uint liquidityOut;
        uint startDate;
        uint16 lockedDays;
    }

    struct Liquidity {
        uint total;
        uint unlocked;
        uint locked30Days;
        uint locked60Days;
        uint locked90Days;
    }

    // user address => user's liquidity position
    mapping(address => LiquidityPosition[]) private liquidityPositions;

    // days => total rewards per day
    mapping(uint => uint) private dayRewards;

    // days => total liquidity per day
    mapping(uint => Liquidity) private dayLiquiditys;

    // locked days => rate
    mapping(uint16 => uint) private lockedRewardRate;


    modifier onlyTreasury() {
        assert(treasury != address(0) && treasury == _msgSender());
        _;
    }

    receive() external payable {
        depositFromTreasury(0);
    }

    // Replace constract
    function initialize(uint _rate0, uint _rate30, uint _rate60, uint _rate90) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        lockedRewardRate[0] = _rate0;
        lockedRewardRate[30] = _rate30;
        lockedRewardRate[60] = _rate60;
        lockedRewardRate[90] = _rate90;

        initialDay = block.timestamp.div(1 days);
    }

    /**
    * @dev Add daily rewards
    * @param _rewards Total rewards added
    * @param _startDate Put in rewards start date (milliseconds, include this day)
    * @param _endDate Put in rewards end date (milliseconds, exclude this day)
    * @return rewardsPerDay rewards per day
    * @return durationDays rewards duration days
    */
    function addRewards(uint _rewards, uint _startDate, uint _endDate) external override returns(uint rewardsPerDay, uint durationDays) {
        
        uint startDay = _startDate.div(1000).div(1 days);
        uint endDay = _endDate.div(1000).div(1 days);

        require(startDay >= block.timestamp.div(1 days) && endDay > startDay);

        _transferFrom(_msgSender(), address(this), _rewards);

        totalRewards += _rewards;

        durationDays = endDay.sub(startDay);
        rewardsPerDay = _rewards.div(durationDays);

        for (uint i = startDay; i < endDay; i++) {
            dayRewards[i] += rewardsPerDay;
        }

        emit AddRewards(_msgSender(), rewardsPerDay, durationDays);
    }

    /**
    * @dev Update locked reward rate
    * @param _lockedDays Lock days
    * @param _rate Rewards rate after lock expires
    * @return unlocked New unlocked rewards rate
    * @return locked30Days New locked 30 days rewards rate
    * @return locked60Days New locked 60 days rewards rate
    * @return locked90Days New locked 90 days rewards rate
    */
    function updateLockedRewardRate(uint16 _lockedDays, uint _rate) external override onlyOwner returns(uint unlocked, uint locked30Days, uint locked60Days, uint locked90Days) {
        require(_rate != 0);
        require(lockedRewardRate[_lockedDays] != 0);
        lockedRewardRate[_lockedDays] = _rate;
        
        (unlocked, locked30Days, locked60Days, locked90Days) = getLockedRewardRate();
        emit UpdateLockedRewardRate(_msgSender(), unlocked, locked30Days, locked60Days, locked90Days);
    }

    /**
    * @dev Get locked reward rate
    * @return unlocked Unlocked rewards rate
    * @return locked30Days Locked 30 days rewards rate
    * @return locked60Days Locked 60 days rewards rate
    * @return locked90Days Locked 90 days rewards rate
    */
    function getLockedRewardRate() public view override returns(uint unlocked, uint locked30Days, uint locked60Days, uint locked90Days) {
        unlocked = lockedRewardRate[0];
        locked30Days = lockedRewardRate[30];
        locked60Days = lockedRewardRate[60];
        locked90Days = lockedRewardRate[90];
    }

    /**
    * @dev Add token and ether to provide liquidity (a relative ratio of ether must be carried)
    * @param _amount Added token amount, must be approved first
    * @param _lockedDays Locked 0 ,30, 60, 90 days
    * @param _ratioMax Maximum ratio, prevent the ratio shift too much
    * @param _ratioMin Minimum ratio, prevent the ratio shift too much
    * @return liquidity Added liquidity
    */
    function addLiquidity(uint _amount, uint16 _lockedDays, uint _ratioMax, uint _ratioMin) external override payable nonReentrant returns(uint liquidity) {
        require(_amount != 0 && msg.value != 0);
        uint rate = lockedRewardRate[_lockedDays];
        require(rate != 0);

        uint ratio = getRatio();
        require(ratio <= _ratioMax && ratio >= _ratioMin);

        (uint amountToken, uint amountWei) = _getDesiredAmount(_amount, msg.value, ratio);
        require(amountToken != 0 && amountWei != 0);

        _transferFrom(_msgSender(), address(this), amountToken);

        liquidity = sqrt(amountToken.mul(amountWei));

        _setLiquidity(liquidity, _lockedDays);

        totalLiquidity += liquidity;
        tokenReserve += amountToken;
        currencyReserve += amountWei;

        // refund
        if (msg.value > amountWei) _transferCurrency(_msgSender(), msg.value - amountWei);

        emit AddLiquidity(_msgSender(), amountToken, amountWei);
    }

    function _setLiquidity(uint _amount, uint16 _lockedDays) private {
        liquidityPositions[_msgSender()].push(LiquidityPosition(_amount, 0, block.timestamp, _lockedDays));

        uint target = block.timestamp.div(1 days).add(1);
        Liquidity memory liquidity = dayLiquiditys[target];
        if (liquidity.total == 0) {
            (uint total, uint unlocked, uint locked30Days, uint locked60Days, uint locked90Days) = _getLiquiditys(target);
            liquidity.total = total;
            liquidity.unlocked = unlocked;
            liquidity.locked30Days = locked30Days;
            liquidity.locked60Days = locked60Days;
            liquidity.locked90Days = locked90Days;
        }
        liquidity.total += _amount;
        if (_lockedDays == 0) {
            liquidity.unlocked += _amount;
            
        } else if (_lockedDays == 30) {
            liquidity.locked30Days += _amount;

        } else if (_lockedDays == 60) {
            liquidity.locked60Days += _amount;

        } else if(_lockedDays == 90) {
            liquidity.locked90Days += _amount;
        }
        dayLiquiditys[target] = liquidity;
    }

    /**
    * @dev Get total count of address' position
    * @param _address Query address
    * @return Total count of position
    */
    function countPositions(address _address) public override view returns(uint) {
        return liquidityPositions[_address].length;
    }

    /**
    * @dev Get ratio of token : currency
    * @return Ratio of token : currency
    */
    function getRatio() public override view returns(uint) {
        (uint112 reserve0, uint112 reserve1,) = abi.decode(PAIR.functionStaticCall(abi.encodeWithSelector(GET_RESERVES)), (uint112, uint112, uint32));
        return reserve0.mul(10 ** decimals()).div(reserve1);
    }

    function _getDesiredAmount(uint _amountToken, uint _amountWei, uint _ratio) private pure returns(uint amountToken, uint amountWei) {
        require(_amountToken != 0 && _amountWei != 0 && _ratio != 0);

        uint amountWeiDesired = _amountToken.mul(10 ** decimals()).div(_ratio);
        if (_amountWei >= amountWeiDesired) {
            amountToken = _amountToken;
            amountWei = amountWeiDesired;
        } else {
            amountToken = _amountWei.mul(_ratio).div(10 ** decimals());
            amountWei = _amountWei;
        }
    }

    /**
    * @dev Remove liquidity to get token, ether and rewards
    * @param _idx Position's index
    * @param _liquidityOut Remove liquidity amount
    * @return amountToken Retrieve token
    * @return amountWei Retrieve ether
    * @return rewards Total rewards
    */
    function removeLiquidity(uint _idx, uint _liquidityOut) external override nonReentrant returns(uint amountToken, uint amountWei, uint rewards) {
        require(_idx < countPositions(_msgSender()));

        (uint liquidityIn, uint liquidityOut, uint startDate, uint16 lockedDays) = getLiquidityPosition(_msgSender(), _idx);
        require(liquidityIn >= liquidityOut.add(_liquidityOut));

        (amountToken, amountWei) = _liquidityToTokenAmount(_liquidityOut);
        rewards = _calcRewards(startDate, lockedDays, _liquidityOut);

        (uint token, uint currency) = getBalance();
        require(currency >= amountWei && token >= amountToken.add(rewards));

        liquidityPositions[_msgSender()][_idx].liquidityOut += _liquidityOut;

        totalRewards -= rewards;
        totalLiquidity -= _liquidityOut;
        tokenReserve -= amountToken;
        currencyReserve -= amountWei;

        _transfer(_msgSender(), amountToken.add(rewards));
        _transferCurrency(_msgSender(), amountWei);

        emit RemoveLiquidity(_msgSender(), amountToken, amountWei, rewards);
    }

    function _liquidityToTokenAmount(uint _liquidity) private view returns(uint amountToken, uint amountWei) {
        (uint token, uint currency) = getReserves();
        amountToken = token.mul(_liquidity).div(totalLiquidity);
        amountWei = currency.mul(_liquidity).div(totalLiquidity);
    }

    function _calcRewards(uint _startDate, uint16 _lockedDays, uint _liquidityOut) private view returns(uint) {

        uint startDay = _startDate.div(1 days).add(1);
        uint endDay = block.timestamp.div(1 days);

        if (startDay.add(_lockedDays) < endDay) {
            return 0;
        }

        uint rewards;
        Liquidity memory tempLiquidity;
        for (uint i = startDay; i < endDay; i++) {
            if (dayLiquiditys[i].total != 0) {
                tempLiquidity = dayLiquiditys[i];
            }
            
            uint rewardPacket = _getRewardPacket(tempLiquidity, dayRewards[i], _lockedDays);
            
            uint totalLiquidityByDay = _lockedDays == 0 ? tempLiquidity.unlocked : _lockedDays == 30 ? tempLiquidity.locked30Days : _lockedDays == 60 ? tempLiquidity.locked60Days : _lockedDays == 90 ? tempLiquidity.locked90Days : 0;
            rewards += rewardPacket.mul(_liquidityOut).div(totalLiquidityByDay);
        }
        return rewards;
    }

    function _getRewardPacket(Liquidity memory _liquidity, uint _totalReward, uint16 _lockedDays) private view returns(uint) {
        (uint raw0, uint raw30, uint raw60, uint raw90) = _getRawWeight(_liquidity.unlocked, _liquidity.locked30Days, _liquidity.locked60Days, _liquidity.locked90Days);
        uint target = _lockedDays == 0 ? raw0 : _lockedDays == 30 ? raw30 : _lockedDays == 60 ? raw60 : _lockedDays == 90 ? raw90 : 0;
        uint weight = _normalizedWeight(target, raw0, raw30, raw60, raw90);

        // day's total reward in selected lock pool
        return _totalReward.mul(weight).div(10 ** decimals());
    }

    function _getRawWeight(uint _share0, uint _share30, uint _share60, uint _share90) private view returns(uint raw0, uint raw30, uint raw60, uint raw90) {
            uint total = _share0.add(_share30).add(_share60).add(_share90);
            raw0 = _calcRawWeight(_share0, total, 0);
            raw30 = _calcRawWeight(_share30, total, 30);
            raw60 = _calcRawWeight(_share60, total, 60);
            raw90 = _calcRawWeight(_share90, total, 90);
    }

    function _calcRawWeight(uint _tokens, uint _total, uint16 _lockedDays) private view returns(uint) {
            uint percentage = _tokens.mul(10 ** decimals()).div(_total);
            uint rate = lockedRewardRate[_lockedDays];
            return percentage.mul(rate).div(10 ** decimals());
    }

    function _normalizedWeight(uint _target, uint _raw0, uint _raw30, uint _raw60, uint _raw90) private pure returns(uint) {
        uint totalWeight = _raw0.add(_raw30).add(_raw60).add(_raw90);
        return _target.mul(10 ** decimals()).div(totalWeight);
    }

    /**
    * @dev Get provide daily total rewards by timestamp
    * @param _timestamp Milliseconds
    * @return Total rewards by day
    */
    function getRewards(uint _timestamp) external override view returns(uint) {
        require(_timestamp != 0);
        uint day = _timestamp.div(1000).div(1 days);
        require(day >= initialDay);
        return dayRewards[day];
    }

    /**
    * @dev Get total liquidty by timestamp
    * @param _timestamp Milliseconds
    * @return total Total liquidity by day
    * @return unlocked Total unlocked liquidity by day
    * @return locked30Days Total locked 30 days liquidity by day
    * @return locked60Days Total locked 30 days liquidity by day
    * @return locked90Days Total locked 30 days liquidity by day
    */
    function getLiquiditys(uint _timestamp) external override view returns(uint total, uint unlocked, uint locked30Days, uint locked60Days, uint locked90Days) {
        require(_timestamp != 0);
        return _getLiquiditys(_timestamp.div(1000).div(1 days));
    }

    function _getLiquiditys(uint _day) private view returns(uint total, uint unlocked, uint locked30Days, uint locked60Days, uint locked90Days) {
        require(_day >= initialDay);
        uint day = _day;
        while (dayLiquiditys[day].total == 0 && day > initialDay) {
            day--;
        }
        Liquidity storage liquidity = dayLiquiditys[day];
        total = liquidity.total;
        unlocked = liquidity.unlocked;
        locked30Days = liquidity.locked30Days;
        locked60Days = liquidity.locked60Days;
        locked90Days = liquidity.locked90Days;
    }

    /**
    * @dev Get liquidity position
    * @param _address Query address
    * @param _idx Position's index
    * @return liquidityIn Total provides liquidity by position
    * @return liquidityOut Retrieve liquidity in this position
    * @return startDate Start date(seconds)
    * @return lockedDays Locked days
    */
    function getLiquidityPosition(address _address, uint _idx) public override view returns(uint liquidityIn, uint liquidityOut, uint startDate, uint16 lockedDays) {
        LiquidityPosition storage position = liquidityPositions[_address][_idx];
        liquidityIn = position.liquidityIn;
        liquidityOut = position.liquidityOut;
        startDate = position.startDate;
        lockedDays = position.lockedDays;
    }

    /**
    * @dev Update treasury contract's address
    * @param _address Treasury contract's address
    */
    function updateTreasury(address _address) external override onlyOwner {
        treasury = _address;

        emit UpdateTreasury(_msgSender(), treasury);
    }

    /**
    * @dev Deposit token and ether from treasury contract
    * @param _amountToken Treasury deposit token amount, must be approved first
    * @return amountToken Treasury deposit token amount
    * @return amountWei Treasury deposit ether amount
    */
    function depositFromTreasury(uint _amountToken) public override payable onlyTreasury returns(uint amountToken, uint amountWei) {
        if (_amountToken > 0) {
            _transferFrom(_msgSender(), address(this), _amountToken);
        }

        amountToken = _amountToken;
        amountWei = msg.value;
        emit DepositFromTreasury(_msgSender(), _amountToken, msg.value);
    }

    /**
    * @dev Withdraw token and ether to treasury contract
    * @param _amountToken Withdraw token amount
    * @param _amountWei Withdraw ether amount
    * @return amountToken Withdraw token amount
    * @return amountWei Withdraw ether amount
    */
    function withdrawToTreasury(uint _amountToken, uint _amountWei) external override onlyTreasury returns(uint amountToken, uint amountWei) {
        if (_amountToken > 0) {
            _transfer(_msgSender(), _amountToken);
        }
        if (_amountWei > 0) {
            _transferCurrency(_msgSender(), _amountWei);
        }

        amountToken = _amountToken;
        amountWei = _amountWei;
        emit WithdrawToTreasury(_msgSender(), amountToken, amountWei);
    }

    function _transferFrom(address _from, address _to, uint _amount) private {
        require(_to != address(0) && _amount > 0);
        TOKEN.functionCall(abi.encodeWithSelector(TRANSFER_FROM, _from, _to, _amount));
    }

    function _transfer(address _to, uint _amount) private {
        require(_to != address(0) && _amount > 0);
        TOKEN.functionCall(abi.encodeWithSelector(TRANSFER, _to, _amount));
    }

    function _transferCurrency(address _to, uint256 _amount) private {
        (bool success, ) = _to.call{value: _amount}(new bytes(0));
        require(success);
    }

    /**
    * @dev Get reserves token and ether
    * @return token Total reserves of token
    * @return currency Total reserves of ether(wei)
    */
    function getReserves() public override view returns(uint token, uint currency) {
        token = tokenReserve;
        currency = currencyReserve;
    }

    /**
    * @dev Get real-time balance
    * @return token Real-time balance of token
    * @return currency Real-time balance of ether(wei)
    */
    function getBalance() public override view returns(uint token, uint currency) {
        token = abi.decode(TOKEN.functionStaticCall(abi.encodeWithSelector(BALANCE_OF, address(this))), (uint));
        currency = address(this).balance;
    }

    /**
    * @dev Get the number of decimals 
    * @return The number of decimals 
    */
    function decimals() public override pure returns(uint8) {
        return 18;
    }

    /**
    * @dev Math sqrt
    * @param x Input number
    * @return The number of sqrt(x)
    */
    function sqrt(uint x) public pure returns(uint) {
        uint z = (x + 1 ) / 2;
        uint y = x;
        while (z < y) {
            y = z;
            z = ( x / z + z ) / 2;
        }
        return y;
    }
}