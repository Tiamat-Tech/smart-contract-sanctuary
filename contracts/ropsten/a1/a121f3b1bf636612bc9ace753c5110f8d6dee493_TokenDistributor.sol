pragma solidity ^0.4.24;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting &#39;a&#39; not being zero, but the
    // benefit is lost if &#39;b&#39; is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to relinquish control of the contract.
   */
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(owner);
    owner = address(0);
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function transferOwnership(address _newOwner) public onlyOwner {
    _transferOwnership(_newOwner);
  }

  /**
   * @dev Transfers control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function _transferOwnership(address _newOwner) internal {
    require(_newOwner != address(0));
    emit OwnershipTransferred(owner, _newOwner);
    owner = _newOwner;
  }
}

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract TokenHandler is Ownable {

    address public targetToken;

    constructor ( address _targetToken) public Ownable() {
        setTargetToken(_targetToken);
    }

    function getTokenBalance(address _token) public view returns (uint256) {
        ERC20Basic token = ERC20Basic(_token);
        return token.balanceOf(address(this));
    }

    function setTargetToken (address _targetToken) public onlyOwner returns (bool) {
      require(targetToken == 0x0, &#39;Target token already set&#39;);
      targetToken = _targetToken;
      return true;
    }

    function _transfer (address _token, address _recipient, uint256 _value) internal {
        ERC20Basic token = ERC20Basic(_token);
        token.transfer(_recipient, _value);
    }
}

contract TokenDistributor is TokenHandler {
    using SafeMath for uint;

    address[] public stakeHolders;
    uint256 public maxStakeHolders;
    event InsufficientTokenBalance( address indexed _token );
    event TokensDistributed( address indexed _token, uint256 _total );

    constructor ( address _targetToken, uint256 _totalStakeHolders, address[] _stakeHolders) public
    TokenHandler(_targetToken) {
        maxStakeHolders = _totalStakeHolders;
        if (_stakeHolders.length > 0) {
            for (uint256 count = 0; count < _stakeHolders.length && count < _totalStakeHolders; count++) {
                if (_stakeHolders[count] != 0x0) {
                    _setStakeHolder(_stakeHolders[count]);
                }
            }
        }
    }

    function isDistributionDue (address _token) public view returns (bool) {
        return getTokenBalance(_token) > 1;
    }

    function isDistributionDue () public view returns (bool) {
        return isDistributionDue(targetToken);
    }

    function countStakeHolders () public view returns (uint256) {
        return stakeHolders.length;
    }

    function getPortion (uint256 _total) public view returns (uint256) {
        return _total.div(stakeHolders.length);
    }

    function _setStakeHolder (address _stakeHolder) internal onlyOwner returns (bool) {
        require(countStakeHolders() < maxStakeHolders, "Max StakeHolders set");
        stakeHolders.push(_stakeHolder);
        return true;
    }

    function _distribute (address _token) internal returns (bool) {
        uint256 balance = getTokenBalance(_token);
        uint256 perStakeHolder = getPortion(balance);

        if (balance < 1) {
            emit InsufficientTokenBalance(_token);
            return false;
        } else {
            for (uint256 count = 0; count < stakeHolders.length; count++) {
                _transfer(_token, stakeHolders[count], perStakeHolder);
            }

            uint256 newBalance = getTokenBalance(_token);
            if (newBalance > 0 && getPortion(newBalance) == 0) {
                _transfer(_token, owner, newBalance);
            }

            emit TokensDistributed(_token, balance);
            return true;
        }
    }

    function distribute () public returns (bool) {
        require(targetToken != 0x0, &#39;Target token not set&#39;);
        return _distribute(targetToken);
    }

    function () public {
        distribute();
    }
}