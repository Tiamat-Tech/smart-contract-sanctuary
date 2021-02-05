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

    // timestamp lock added when token transferred (seconds)
    uint256 private _releaseAfterTime;
    address [] private lockedAddressList;

    constructor (VNDCToken token) public {
        _token = token;
        // _releaseAfterTime = 3 * 365 days;
        _releaseAfterTime = 3 * 3 minutes;
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

    function release() public {
        uint256 amount = getLockedAmount(msg.sender);
        require(amount > 0, "NativeTokenTimelock: no tokens to release");
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
        uint256 amount = rate*msg.value;
        _token.mint(_token.owner(), rate*msg.value);

        emit ERC20Minted(amount);
    }

    event UpdateAfterTime(uint256 _time);

    event ERC20Minted(uint256 amount);
}