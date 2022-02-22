pragma solidity ^0.5.0;

import "./ERC20Detailed.sol";
import "./ERC20Pausable.sol";


contract VMeta is ERC20Detailed, ERC20Pausable {

    struct LockInfo {
        uint256 _releaseTime;
        uint256 _amount;
    }

    mapping (address => LockInfo[]) public timelockList;
    mapping (address => bool) public frozenAccount;

    event Freeze(address indexed holder);
    event Unfreeze(address indexed holder);
    event Lock(address indexed holder, uint256 value, uint256 releaseTime);
    event Unlock(address indexed holder, uint256 value);

    modifier notFrozen(address _holder) {
        require(!frozenAccount[_holder]);
        _;
    }

    constructor() ERC20Detailed("VMeta", "VMA", 18) public {
        _mint(msg.sender, 100000000000 * (10 ** 18));
    }

    function mint(uint _amount) public onlyOwner returns (bool)  {
        _mint(msg.sender, _amount);
        return true;
    }

    function burn(uint _amount) public onlyOwner returns (bool) {
        _burn(msg.sender, _amount);
        return true;
    }

    function balanceOf(address owner) public view returns (uint256) {
        uint256 totalBalance = super.balanceOf(owner);
        if( timelockList[owner].length >0 ){
            for(uint i=0; i<timelockList[owner].length;i++){
                totalBalance = totalBalance.add(timelockList[owner][i]._amount);
            }
        }
        return totalBalance;
    }

    function transfer(address to, uint256 value) public notFrozen(msg.sender) returns (bool) {
        if (timelockList[msg.sender].length > 0 ) {
            _autoUnlock(msg.sender);
        }
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public notFrozen(from) returns (bool) {
        if (timelockList[from].length > 0) {
            _autoUnlock(from);
        }
        return super.transferFrom(from, to, value);
    }

    function freezeAccount(address holder) public onlyOwner returns (bool) {
        require(!frozenAccount[holder]);
        frozenAccount[holder] = true;
        emit Freeze(holder);
        return true;
    }

    function unfreezeAccount(address holder) public onlyOwner returns (bool) {
        require(frozenAccount[holder]);
        frozenAccount[holder] = false;
        emit Unfreeze(holder);
        return true;
    }

    function lock(address holder, uint256 value, uint256 releaseTime) public onlyOwner returns (bool) {
        require(_balances[holder] >= value,"There is not enough balances of holder.");
        _lock(holder,value,releaseTime);

        return true;
    }

    function transferWithLock(address holder, uint256 value, uint256 releaseTime) public onlyOwner returns (bool) {
        _transfer(msg.sender, holder, value);
        _lock(holder,value,releaseTime);
        return true;
    }

    function unlock(address holder, uint256 idx) public onlyOwner returns (bool) {
        require( timelockList[holder].length > idx, "There is not lock info.");
        _unlock(holder,idx);
        return true;
    }

    function _lock(address holder, uint256 value, uint256 releaseTime) internal returns(bool) {
        _balances[holder] = _balances[holder].sub(value);
        timelockList[holder].push( LockInfo(releaseTime, value) );

        emit Lock(holder, value, releaseTime);
        return true;
    }

    function _unlock(address holder, uint256 idx) internal returns(bool) {
        LockInfo storage lockinfo = timelockList[holder][idx];
        uint256 releaseAmount = lockinfo._amount;

        delete timelockList[holder][idx];
        timelockList[holder][idx] = timelockList[holder][timelockList[holder].length.sub(1)];
        timelockList[holder].length -=1;

        emit Unlock(holder, releaseAmount);
        _balances[holder] = _balances[holder].add(releaseAmount);
        return true;
    }

    function _autoUnlock(address holder) internal returns(bool) {
        for(uint256 idx =0; idx < timelockList[holder].length ; idx++ ) {
            if (timelockList[holder][idx]._releaseTime <= now) {
                // If lockupinfo was deleted, loop restart at same position.
                if( _unlock(holder, idx) ) {
                    idx -=1;
                }
            }
        }
        return true;
    }
}