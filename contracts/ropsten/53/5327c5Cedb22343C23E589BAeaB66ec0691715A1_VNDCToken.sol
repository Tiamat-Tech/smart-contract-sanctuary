pragma solidity ^0.5.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';
import '@openzeppelin/contracts/ownership/Ownable.sol';

contract VNDCToken is ERC20, ERC20Detailed, ERC20Mintable, ERC20Pausable, ERC20Burnable, Ownable {

  // additional variables for use if transaction fees ever became necessary
  uint public basisPointsRate = 0;
  uint public maximumFee = 0;
  uint public minimumFee = 0;
  uint public mintingRate = 0;
  mapping (address => bool) public isBlackListed;

  constructor() public ERC20Detailed("VNDC", "VNDC", 0) {
    mint(owner(), 100000000 * 10 ** uint256(decimals())); // Initial supply at 100M token
  }

  function transfer(address _to, uint _value) public whenNotPaused returns (bool) {
    require(!isBlackListed[_to]);
    require(!isBlackListed[msg.sender]);

    uint fee = (_value.mul(basisPointsRate)).div(10000);
    if (fee > maximumFee) {
      fee = maximumFee;
    }
    uint sendAmount = _value.sub(fee);

    if (fee > 0) {
      super.transfer(owner(), fee);
    }

    return super.transfer(_to, sendAmount);
  }

  function transferFrom(address _from, address _to, uint _value) public whenNotPaused returns (bool) {
    require(!isBlackListed[_from]);
    require(!isBlackListed[_to]);
    require(!isBlackListed[msg.sender]);

    uint fee = (_value.mul(basisPointsRate)).div(10000);
    if (fee > maximumFee) {
      fee = maximumFee;
    }
    uint sendAmount = _value.sub(fee);

    if (fee > 0) {
      super.transfer(owner(), fee);
      ERC20._approve(_from, _to, sendAmount);
    }

    return super.transferFrom(_from, _to, sendAmount);
  }

  function setParams(uint newBasisPoints, uint newMaxFee, uint newMinFee) public onlyOwner returns (bool) {
    // Ensure transparency by hardcoding limit beyond which fees can never be added
    basisPointsRate = newBasisPoints;
    minimumFee = newMinFee;
    maximumFee = newMaxFee;
    emit Params(basisPointsRate, maximumFee, minimumFee);

    return true;
  }

  function setMintingRate(uint newRate) public onlyOwner returns (bool) {
    mintingRate = newRate;
    emit UpdateMintingRate(newRate);

    return true;
  }

  function getBlackListStatus(address _maker) external view returns (bool) {
    return isBlackListed[_maker];
  }

  function addBlackList (address _evilUser) public onlyOwner returns (bool) {
    isBlackListed[_evilUser] = true;
    emit AddedBlackList(_evilUser);

    return true;
  }

  function removeBlackList (address _clearedUser) public onlyOwner returns (bool) {
    isBlackListed[_clearedUser] = false;
    emit RemovedBlackList(_clearedUser);

    return true;
  }

  function destroyBlackFunds (address _blackListedUser) public onlyOwner returns (bool) {
    require(isBlackListed[_blackListedUser]);
    uint dirtyFunds = balanceOf(_blackListedUser);
    ERC20._burn(_blackListedUser, dirtyFunds);
    emit DestroyedBlackFunds(_blackListedUser, dirtyFunds);

    return true;
  }

  event DestroyedBlackFunds(address _blackListedUser, uint _balance);

  event AddedBlackList(address _user);

  event RemovedBlackList(address _user);

  event Params(uint feeBasisPoints, uint maxFee, uint minFee);

  event UpdateMintingRate(uint newMintingRate);

}

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