// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import { SafeMath } from "./SafeMath.sol";
import { Ownable } from "./Ownable.sol";

interface IERC20 {
  function transfer(address recipient, uint256 amount) external;
  function balanceOf(address owner) external view returns (uint256);
  function transferFrom(address _from, address _to, uint256 _value) external;
}

contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}


contract MultiDelegate is Ownable, ReentrancyGuard {
  address[] public delegators;
  IERC20 private voteToken;
  mapping(address => mapping(address => uint256)) delegateAmount;
  mapping(address => uint256) public delegatorAmount;

  constructor(address _voteToken) {
    voteToken = IERC20(_voteToken);
  }

  function delegate(address delegator, uint256 amount) public {
    uint256 i;
    bool _isin = false;
    for (i = 0; i < delegators.length; i++) {
      if(delegators[i] == delegator) {
        _isin = true;
        break;
      }
    }
    require(_isin, "No delegator!");
    require(voteToken.balanceOf(msg.sender)>=amount, "Insuffient Funds!");
    uint256 curAmount = delegateAmount[msg.sender][delegator] > 0 ? delegateAmount[msg.sender][delegator]: 0;
    uint256 curDelegatorAmount = delegatorAmount[delegator] > 0 ? delegatorAmount[delegator] : 0;
    delegateAmount[msg.sender][delegator] = curAmount + amount;
    delegatorAmount[delegator] = curDelegatorAmount + amount;
    voteToken.transferFrom(msg.sender, address(this), amount);
    emit delegateAdded(msg.sender, delegator, amount);
  }

  function addDelegator(address delegator) external onlyOwner {
    delegators.push(delegator);
    emit delegatorAdded(delegator);
  }

  function _removeDelegator(uint256 index) internal {
    delegators[index] = delegators[delegators.length - 1];
    delegators.pop();
  }

  function removeDelegator(address delegator) external onlyOwner {
    for(uint256 i=0;i<delegators.length;i++) {
      if(delegator == delegators[i]) {
        _removeDelegator(i);
        break;
      }
    }
    emit delegatorRemoved(delegator);
  }

  function getDelegators() external view returns (address[] memory) {
    return delegators;
  }

  function getDelegatorState(address delegator) external view returns (uint256) {
    return delegatorAmount[delegator];
  }

  function withdraw() external onlyOwner nonReentrant {
    uint256 balance = voteToken.balanceOf(address(this));
    voteToken.transfer(msg.sender, balance);
    emit withdrawVote(balance);
  }

  // Events
  event delegateAdded(address voter, address delegator, uint256 amount);
  event delegatorAdded(address delegator);
  event withdrawVote(uint256 withdrawAmount);
  event delegatorRemoved(address delegator);
}