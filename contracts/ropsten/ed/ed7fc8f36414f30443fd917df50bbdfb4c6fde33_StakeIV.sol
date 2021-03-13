/**
 *Submitted for verification at Etherscan.io on 2021-03-13
*/

pragma solidity ^0.4.19;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
 
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b; assert(a == 0 || c / a == b); return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b; return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a); return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b; assert(c >= a); return c;
    }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
 
contract Ownable {
    address public owner;
    
    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
     
    function Ownable() public {owner = msg.sender;}

    /**
     * @dev Throws if called by any account other than the owner.
     */
     
    modifier onlyOwner() {require(msg.sender == owner);_;}

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
     
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0)); owner = newOwner;}
}

contract Destructible is Ownable {}

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
 
contract ERC20Basic {
    uint256 public totalSupply;
    function balanceOf(address who) public constant returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
 
contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) internal constant returns (uint256);
    function transferFrom(address from, address to, uint256 value) internal returns (bool);
    function approve(address spender, uint256 value) internal returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title InternalPoSMinting
 * @dev the interface of InternalPoSMinting
 */
 
contract InternalPoSMinting {
    uint256 public stakeStartTime;
    uint256 public stakeMinAge;
    uint256 public stakeMaxAge;
    function mint() public returns (bool);
    function coinAge() internal constant returns (uint256);
    function annualInterest() internal constant returns (uint256);
    event Mint(address indexed _address, uint _reward);
}

//------------------------------------------------------------------------------
//Contructor
//------------------------------------------------------------------------------

contract StakeIV is ERC20, InternalPoSMinting, Ownable {
    using SafeMath for uint256;

    string public name = "StakeIV";
    string public symbol = "STAKIV";
    uint public decimals = 18;

    uint public chainStartTime; //chain start time
    uint public chainStartBlockNumber; //chain start block number
    uint public stakeStartTime; //stake start time
    uint public stakeMinAge = 1 days; //minimum age for coin age: 1 days
    uint public stakeMaxAge = 30 days; //stake age of full weight: 30 days
    uint public defaultRate = 10**17; //default 10% annual interest

    uint public totalSupply;
    uint public maxTotalSupply;
    uint public totalInitialSupply;

    struct transferInStruct{uint128 amount; uint64 time;}

    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;
    mapping(address => transferInStruct[]) transferIns;

    event Burn(address indexed burner, uint256 value);
    event ChangeMaxTotalSupply(uint256 value);

    /**
     * @dev Fix for the ERC20 short address attack.
     */
     
    modifier onlyPayloadSize(uint size) {
        require(msg.data.length >= size + 4);
        _;
    }

    modifier PoSMinter() {
        require(totalSupply < maxTotalSupply);
        _;
    }

    function StakeIV() public {
        maxTotalSupply = 500000 * (10**decimals);
        totalInitialSupply = 50000 * (10**decimals);
        
        stakeStartTime = now + 5 days;
        chainStartTime = now;
        chainStartBlockNumber = block.number;

        balances[msg.sender] = totalInitialSupply;
        totalSupply = totalInitialSupply;
    }

//------------------------------------------------------------------------------
//ERC20 Function
//------------------------------------------------------------------------------

    function transfer(address _to, uint256 _value) public onlyPayloadSize(2 * 32) returns (bool) {
        if(msg.sender == _to) return mint();
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        if(transferIns[msg.sender].length > 0) delete transferIns[msg.sender];
        uint64 _now = uint64(now);
        transferIns[msg.sender].push(transferInStruct(uint128(balances[msg.sender]),_now));
        transferIns[_to].push(transferInStruct(uint128(_value),_now));
        return true;
    }

    function balanceOf(address _owner) public constant returns (uint256 balance) {
        return balances[_owner];
    }

    function transferFrom(address _from, address _to, uint256 _value) internal onlyPayloadSize(3 * 32) returns (bool) {
        require(_to != address(0));

        var _allowance = allowed[_from][msg.sender];

        // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
        // require (_value <= _allowance);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);
        Transfer(_from, _to, _value);
        if(transferIns[_from].length > 0) delete transferIns[_from];
        uint64 _now = uint64(now);
        transferIns[_from].push(transferInStruct(uint128(balances[_from]),_now));
        transferIns[_to].push(transferInStruct(uint128(_value),_now));
        return true;
    }

    function approve(address _spender, uint256 _value) internal returns (bool) {
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) internal constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
    
    function destroy() public onlyOwner {
        selfdestruct(address(this));
    }

//------------------------------------------------------------------------------
//Internal Proof Of Stake Implementation
//------------------------------------------------------------------------------

    function mint() public PoSMinter returns (bool) {
        if(balances[msg.sender] <= 0) return false;
        if(transferIns[msg.sender].length <= 0) return false;

        uint reward = getMintingReward(msg.sender);
        if(reward <= 0) return false;

        totalSupply = totalSupply.add(reward);
        balances[msg.sender] = balances[msg.sender].add(reward);
        delete transferIns[msg.sender];
        transferIns[msg.sender].push(transferInStruct(uint128(balances[msg.sender]),uint64(now)));

        Mint(msg.sender, reward);
        return true;
    }

    function getBlockNumber() public view returns (uint blockNumber) {
        blockNumber = block.number.sub(chainStartBlockNumber);
    }

    function coinAge() internal constant returns (uint myCoinAge) {
        myCoinAge = getCoinAge(msg.sender,now);
    }

    function annualInterest() internal constant returns (uint interest) {
        uint _now = now;
        interest = defaultRate;
        if((_now.sub(stakeStartTime)).div(365 days) == 0) {
            interest = (1000 * defaultRate).div(100);
        } else if((_now.sub(stakeStartTime)).div(365 days) == 1){
            interest = (500 * defaultRate).div(100);
        } else if((_now.sub(stakeStartTime)).div(365 days) == 2){
            interest = (250 * defaultRate).div(100);
        } else if((_now.sub(stakeStartTime)).div(365 days) == 3){
            interest = (125 * defaultRate).div(100);
        }
    }

    function getMintingReward(address _address) internal constant returns (uint) {
        require((now >= stakeStartTime) && (stakeStartTime > 0));

        uint _now = now;
        uint _coinAge = getCoinAge(_address, _now);
        if(_coinAge <= 0) return 0;

        uint interest = defaultRate;
        if((_now.sub(stakeStartTime)).div(365 days) == 0) {
            interest = (1000 * defaultRate).div(100);
        } else if((_now.sub(stakeStartTime)).div(365 days) == 1){
            interest = (500 * defaultRate).div(100);
        } else if((_now.sub(stakeStartTime)).div(365 days) == 2){
            interest = (250 * defaultRate).div(100);
        } else if((_now.sub(stakeStartTime)).div(365 days) == 3){
            interest = (125 * defaultRate).div(100);
        }

        return (_coinAge * interest).div(365 * (10**decimals));
    }

    function getCoinAge(address _address, uint _now) internal constant returns (uint _coinAge) {
        if(transferIns[_address].length <= 0) return 0;

        for (uint i = 0; i < transferIns[_address].length; i++){
            if( _now < uint(transferIns[_address][i].time).add(stakeMinAge) ) continue;

            uint nCoinSeconds = _now.sub(uint(transferIns[_address][i].time));
            if( nCoinSeconds > stakeMaxAge ) nCoinSeconds = stakeMaxAge;

            _coinAge = _coinAge.add(uint(transferIns[_address][i].amount) * nCoinSeconds.div(1 days));
        }
    }

    function SetStakeStartTime(uint timestamp) public onlyOwner {
        require((stakeStartTime <= 0) && (timestamp >= chainStartTime));
        stakeStartTime = timestamp;
    }

    function burn(uint _value) public onlyOwner {
        require(_value > 0);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        delete transferIns[msg.sender];
        transferIns[msg.sender].push(transferInStruct(uint128(balances[msg.sender]),uint64(now)));

        totalSupply = totalSupply.sub(_value);
        totalInitialSupply = totalInitialSupply.sub(_value);
        maxTotalSupply = maxTotalSupply.sub(_value);

        Burn(msg.sender, _value);
    }
    
    function changeMaxTotalSupply(uint256 _maxTotalSupply) public onlyOwner {
        maxTotalSupply = _maxTotalSupply;
        ChangeMaxTotalSupply(maxTotalSupply);
    }
}