pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


/*
* @Dev to be cleared in deployment - this is for debugging
*/
import "hardhat/console.sol";


contract CarNCToken is Ownable, IERC20 {
    using SafeMath for uint256;
    /**/
    string private constant _name = "Carchain native currency";
    string private constant _symbol = "CarNC";
    uint8 private constant _decimals = 18;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowed;
    uint256 private _coinTotalSupply = 1000000000 * (10 ** uint256(_decimals));


    /**
    * @dev total supply is minted and transferred to the owner
    */
    constructor () {
        _balances[msg.sender] = _coinTotalSupply;
        emit Transfer(address(0), msg.sender, _coinTotalSupply);
    }

    function transfer(address _to, uint256 _value) external override returns (bool) {
        require(_value > 0);
        require(_balances[msg.sender] >= _value);
        require(_balances[_to] + _value > _balances[_to]);


        _balances[msg.sender] = _balances[msg.sender].sub(_value);
        _balances[_to] = _balances[_to].add(_value);

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) external override returns (bool) {
        require(_value > 0);
        require(_balances[_from] >= _value);
        require(_balances[_to] + _value > _balances[_to]);
        require(_allowed[_from][msg.sender] >= _value);

        _balances[_to] = _balances[_to].add(_value);
        _balances[_from] = _balances[_from].sub(_value);
        _allowed[_from][msg.sender] = _allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) view external override returns (uint256) {
        return _balances[_owner];
    }

    function approve(address _spender, uint256 _value) external override returns (bool) {
        _allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) view external override returns (uint256) {
        return _allowed[_owner][_spender];
    }

    function totalSupply() view external override returns (uint256){
        return _coinTotalSupply;
    }

    function decimals() pure public returns (uint8) {
        return _decimals;
    }

    function name() pure public returns (string memory) {
        return _name;
    }

    function symbol() pure public returns (string memory) {
        return _symbol;
    }


}