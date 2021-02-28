pragma solidity ^0.6.0;

import "./access/ManagerRole.sol";

import "./math/SafeMath.sol";

import "./interface/ITRC20.sol";

contract GameContract is ManagerRole {
  using SafeMath for uint256;

  event DepositETH(address player, uint256 amount);
  event DepositUSDT(address player, uint256 amount);
  event TransferETH(address to, uint256 amount);
  event TransferUSDT(address to, uint256 amount);

  // Title contract
  string private _title;
  // USDT token contract
  address private _usdt;

  // Players deposites to contract (buyIn)
  mapping (address => uint256) private _depositesETH;
  // Count wager ETH
  mapping (address => uint256) private _wagerOfETH;
  // Players deposites to contract (buyIn)
  mapping (address => uint256) private _depositesUSDT;
  // Count wager USDT
  mapping (address => uint256) private _wagerOfUSDT;

  constructor () public {
    _title = "GameContract";
  }

  /**
   * @dev Receive ETH
   */
  receive() external payable {}

  /**
   * @dev BuyIn - deposit ETH to the platform
   * @return A boolean that indicates if the operation was successful.
   */
  function depositETH() public payable returns (bool) {
    _depositesETH[msg.sender] = _depositesETH[msg.sender].add(msg.value);
    
    emit DepositETH(msg.sender, msg.value);
    return true;
  }

  /**
   * @dev Function to payout ETH
   * @param to The address that will receive the ETH.
   * @param value The amount of tokens to wager.
   * @return A boolean that indicates if the operation was successful.
   */
  function transferToETH(address payable to, uint256 value) public onlyManager returns (bool) {
    _wagerOfETH[msg.sender] = _wagerOfETH[msg.sender].add(value);
    to.transfer(value);

    emit TransferETH(to, value);
    return true;
  }

  /**
   * @dev BuyIn - deposit USDT to the platform.
   * @param value Amount deposit USDT.
   * @return A boolean that indicates if the operation was successful.
   */
  function depositUSDT(uint256 value) public returns (bool) {
    ITRC20 _token = ITRC20(_usdt);
    _token.transferFrom(msg.sender, address(this), value);

    _depositesUSDT[msg.sender] = _depositesUSDT[msg.sender].add(value);

    emit DepositUSDT(msg.sender, value);
    return true;
  }

  /**
   * @dev BuyIn - deposit USDT to the platform
   * @return A boolean that indicates if the operation was successful.
   */
  function transferToUSDT(address to, uint256 value) public onlyManager returns (bool) {
    ITRC20 _token = ITRC20(_usdt);
    _token.transfer(to, value);

    _wagerOfUSDT[msg.sender] = _wagerOfUSDT[msg.sender].add(value);

    emit TransferUSDT(to, value);
    return true;
  }

  /**
   * @dev Set usdt token contract
   * @param usdt address contract.
   * @return A boolean that indicates if the operation was successful.
   */
  function setUSDTContract(address usdt) public onlyManager returns (bool) {
    _usdt = usdt;
    return true;
  }

  /**
   * @dev Get BuyIn USDT sender
   * @param player Sender deposit.
   * @return A boolean that indicates if the operation was successful.
   */
  function depositOfETH(address player) public view returns (uint256) {
    return _depositesETH[player];
  }

  /**
   * @dev Get count payout ETH
   * @param owner The address that will receive the ETH.
   */
  function wagerOfETH(address owner) public view returns (uint256) {
    return _wagerOfETH[owner];
  }

  /**
   * @dev Get BuyIn USDT sender
   * @param player Sender deposit.
   */
  function depositOfUSDT(address player) public view returns (uint256) {
    return _depositesUSDT[player];
  }

  /**
   * @dev Get count payout USDT
   * @param owner The address that will receive the USDT.
   */
  function wagerOfUSDT(address owner) public view returns (uint256) {
    return _wagerOfUSDT[owner];
  }

  /**
   * @dev Get usdt token contract
   */
  function getUSDTContract() public view returns (address) {
    return _usdt;
  }
}