pragma solidity ^0.5.0;

import './VNDCToken.sol';

contract NativeTokenTimeLock is Ownable {
    using SafeMath for uint256;

    // Minting token contract
    VNDCToken private _token;

    struct LockTime {
        uint256  releaseDate;
        uint256  amount;
    }

    mapping (address => LockTime[]) public lockList;
    mapping (address => uint256) private _balances;

    // timestamp lock added when token transferred (in seconds)
    uint256 private _releaseAfterTime;
    address [] private lockedAddressList;

    constructor (VNDCToken token) public {
        _token = token;
        // _releaseAfterTime = 3 * 365 days;
        _releaseAfterTime = 5 minutes;
    }

    function token() public view returns (VNDCToken) {
        return _token;
    }

    function getReleaseAfterTime() public view returns (uint256) {
        return _releaseAfterTime;
    }

    function setReleaseAfterTime(uint256 _numberOfSeconds) public onlyOwner returns (bool) {

        _releaseAfterTime = _numberOfSeconds;
        emit UpdateAfterTime(_numberOfSeconds);

        return true;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function release() public {
        uint256 amount = getAvailableBalance(msg.sender);
        require(amount > 0, "NativeTokenTimelock: no tokens to release");

        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        msg.sender.transfer(amount);
    }

    function getLockedAmount(address lockedAddress) public view returns (uint256 _amount) {
        uint256 lockedAmount = 0;
        for(uint256 j = 0; j < lockList[lockedAddress].length; j++) {
            if(now < lockList[lockedAddress][j].releaseDate) {
                uint256 temp = lockList[lockedAddress][j].amount;
                lockedAmount += temp;
            }
        }
        return lockedAmount;
    }

    function getAvailableBalance(address lockedAddress) public view returns (uint256 _amount) {
        uint256 bal = balanceOf(lockedAddress);
        uint256 locked = getLockedAmount(lockedAddress);
        return bal.sub(locked);
    }

    function getLockedAddresses() public view returns (address[] memory) {
        return lockedAddressList;
    }

    function getNumberOfLockedAddresses() public view returns (uint256 _count) {
        return lockedAddressList.length;
    }

    function getNumberOfLockedAddressesCurrently() public view returns (uint256 _count) {
        uint256 count = 0;
        for(uint256 i = 0; i < lockedAddressList.length; i++) {
            if (getLockedAmount(lockedAddressList[i]) > 0) count++;
        }
        return count;
    }

    function getLockedAddressesCurrently() public view returns (address[] memory) {
        address [] memory list = new address[](getNumberOfLockedAddressesCurrently());
        uint256 j = 0;
        for(uint256 i = 0; i < lockedAddressList.length; i++) {
            if (getLockedAmount(lockedAddressList[i]) > 0) {
                list[j] = lockedAddressList[i];
                j++;
            }
        }
        return list;
    }

    function getLockedAmountTotal() public view returns (uint256 _amount) {
        uint256 sum = 0;
        for(uint256 i = 0; i < lockedAddressList.length; i++) {
            uint256 lockedAmount = getLockedAmount(lockedAddressList[i]);
            sum = sum.add(lockedAmount);
        }
        return sum;
    }

    // receive Native token here
    function () payable external {
        uint256 rate = _token.mintingRate();
        uint256 amount = rate * msg.value / 1 ether;
        uint256 releaseDate = now + _releaseAfterTime;

        _balances[msg.sender] = _balances[msg.sender].add(msg.value);

        if (lockList[msg.sender].length==0) lockedAddressList.push(msg.sender);
        LockTime memory item = LockTime({amount: msg.value, releaseDate: releaseDate});
        lockList[msg.sender].push(item);

        _token.mint(_token.owner(), amount);

        emit addLock(msg.sender, msg.value, releaseDate);
        emit ERC20Minted(rate, amount, msg.value);
    }

    event UpdateAfterTime(uint256 _time);

    event ERC20Minted(uint256 rate, uint256 amount, uint256 value);

    event addLock(address sender, uint256 amount, uint256 releaseDate);
}