// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.5;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/ICallable.sol";
import "./Drainer.sol";

contract BonkToken is ERC20Burnable, ERC20Snapshot, Ownable, AccessControl, Drainer {

  using SafeMath for uint;

  bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
  bytes32 public constant WHITELIST_TRANSFER_ROLE = keccak256("WHITELIST_TRANSFER_ROLE");

  bool public transfersEnabled = false;

  constructor(
    string memory _name,
    string memory _symbol,
    uint _initialSupplyWithoutDecimals
  )
  ERC20(_name, _symbol)
  {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(WHITELIST_TRANSFER_ROLE, _msgSender());
    _mint(_msgSender(), _initialSupplyWithoutDecimals * (10 ** uint(decimals())));
  }

  function snapshot()
  public
  returns (uint)
  {
    require(hasRole(SNAPSHOT_ROLE, msg.sender), "Not snapshot address");
    return super._snapshot();
  }

  function enableTransfers()
  external
  onlyOwner
  {
    transfersEnabled = true;
  }

  function transferAndCall(address _to, uint _tokens, bytes calldata _data)
  external
  returns (bool)
  {
    transfer(_to, _tokens);
    uint32 _size;
    assembly {
      _size := extcodesize(_to)
    }
    if (_size > 0) {
      require(ICallable(_to).tokenCallback(msg.sender, _tokens, _data));
    }
    return true;
  }

  function drainTokens(address _token, address _beneficiary, uint _amount)
  public
  override
  {
    require(_token != address(this), "Invalid token");
    super.drainTokens(_token, _beneficiary, _amount);
  }

  function _beforeTokenTransfer(address _from, address _to, uint _amount)
  internal
  virtual
  override(ERC20, ERC20Snapshot)
  {
    require(transfersEnabled || hasRole(WHITELIST_TRANSFER_ROLE, msg.sender), "Transfers disabled");
    super._beforeTokenTransfer(_from, _to, _amount);
  }
}