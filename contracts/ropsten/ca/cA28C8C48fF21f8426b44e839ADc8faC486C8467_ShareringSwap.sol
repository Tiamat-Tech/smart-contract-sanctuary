// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ShareringSwap
 * @dev ShareringSwap contract is Ownable
 **/
contract ShareringSwap is Ownable {
  using SafeMath for uint256;
  IERC20 token;
  address public requester;
  address public approver;
  
  struct typeTxInfo {
    address to;
    uint256 value;
    bytes32 transactionId;
    uint status;
  }
  
  mapping(bytes32 => typeTxInfo) public Txs;
  
  /**
   * RequestSwap
   * @dev Log swap request
   */
  event RequestSwap(bytes32 transactionId, address indexed to, uint256 value);

  /**
   * Reject Swap
   * @dev Log swap approval
   */
  event RejectSwap(bytes32 transactionId, address indexed to, uint256 value);
  
  /**
   * ApprovalSwap
   * @dev Log swap approval
   */
  event ApprovalSwap(bytes32 transactionId, address indexed to, uint256 value);

  /**
   * onlyApprover
   * @dev Throws an error if called by any account other than the approver.
   **/
  modifier onlyApprover() {
    require(msg.sender == approver);
    _;
  }
  
  /**
   * onlyRequester
   * @dev Throws an error if called by any account other than the approver.
   **/
  modifier onlyRequester() {
    require(msg.sender == requester);
    _;
  }
  
  
  /**
   * ShareringSwap
   * @dev ShareringSwap constructor
   **/
  constructor(address _tokenAddr, address _requester, address _approver) {
      require(_tokenAddr != address(0));
      token = IERC20(_tokenAddr);
      requester = _requester;
      approver = _approver;
  }

  /**
   * tokensAvailable
   * @dev returns the number of tokens allocated to this contract
   **/
  function tokensAvailable() public view returns (uint256) {
    return token.balanceOf(address(this));
  }

  /**
   * withdraw
   **/
  function withdraw() onlyOwner public {
    // Transfer tokens back to owner
    uint256 balance = token.balanceOf(address(this));
    assert(balance > 0);
    token.transfer(msg.sender, balance);
  }
  
  /**
   * set Approval Address
   **/
  function setApprover(address _approver) onlyOwner public {
    approver = _approver;
  }
  
   /**
   * set Requester Address
   **/
  function setRequester(address _requester) onlyOwner public {
    requester = _requester;
  }
  
  /**
   * tx info
   * @dev returns the tx info
   **/
  function txInfo(bytes32 _transactionId) public view returns (address, uint256, uint) {
    return (Txs[_transactionId].to, Txs[_transactionId].value, Txs[_transactionId].status);
  }
  
   /**
   * Request swap
   **/
  function requestSwap(bytes32 _transactionId, address _to, uint256 _amount) onlyRequester public {
    require(_to != address(0), "Should be correct target");
    require(_amount > 0, "Should be more than 0");
    Txs[_transactionId].transactionId = _transactionId;
    Txs[_transactionId].to = _to;
    Txs[_transactionId].value = _amount;
    Txs[_transactionId].status = 1;
    emit RequestSwap(_transactionId, _to, _amount);
  }
  
    /**
   * Request multi swap
   **/
  function requestMultiSwap(bytes32[] memory _transactionIds, address[] memory _targets, uint256[] memory _amounts) onlyRequester public {
    require(_transactionIds.length > 0, "Should not be Empty!");
    require(_transactionIds.length == _targets.length, "Should be same!");
    require(_targets.length == _amounts.length, "Should not be Empty!");
    for (uint i = 0; i < _transactionIds.length; i++) {
       requestSwap(_transactionIds[i], _targets[i], _amounts[i]); 
    }  
  }

  
  /**
   * Reject swap
   **/
  function rejectSwap(bytes32 _transactionId) onlyApprover public {
    assert(Txs[_transactionId].status == 1);    
    Txs[_transactionId].status = 3;
    emit RejectSwap(_transactionId, Txs[_transactionId].to, Txs[_transactionId].value);
  }

  /**
   * Reject multi swap
   **/
  function rejectMultiSwap(bytes32[] memory _transactionIds) onlyApprover public {
    for (uint i = 0; i < _transactionIds.length; i++) {
       rejectSwap(_transactionIds[i]); 
    }  
  }

   /**
   * Approve swap
   **/
  function approveSwap(bytes32 _transactionId) onlyApprover public {
    uint256 balance = token.balanceOf(address(this));
    assert(balance > Txs[_transactionId].value);
    assert(Txs[_transactionId].status == 1);
    token.transfer(Txs[_transactionId].to, Txs[_transactionId].value);
    Txs[_transactionId].status = 2;
    emit ApprovalSwap(_transactionId, Txs[_transactionId].to, Txs[_transactionId].value);
  }
  
  
   /**
   * Approve multi swap
   **/
  function approveMultiSwap(bytes32[] memory _transactionIds) onlyApprover public {
    for (uint i = 0; i < _transactionIds.length; i++) {
       approveSwap(_transactionIds[i]); 
    }  
  }
}