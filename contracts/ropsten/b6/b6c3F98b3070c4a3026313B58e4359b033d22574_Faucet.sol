// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol"; 

contract Faucet is AccessControlEnumerable{
  
  mapping(address=>mapping(address=>uint)) expiryOf;
  mapping(address=>address) owner;
  mapping(address=>uint) secs;
  mapping(address=>uint) amounts;

  constructor(address admin, address pcm) {
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
    owner[pcm] = admin;
    secs[pcm] = 600;
    amounts[pcm] = 1 ether; 
  }

  modifier onlyAdmin(){
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "onlyAdmin function");
    _;
  }
  modifier onlyOwner(address token){
    require(owner[token] == _msgSender(), "onlyOwner function");
    _;
  }
  modifier noOwner(address token){
    require(owner[token] == address(0), "noOwner function");
    _;
  }
  
  function setAdmin(address newAdmin) external onlyAdmin{
    _setupRole(DEFAULT_ADMIN_ROLE, newAdmin);    //out of gas
  }
  function unsetAdmin(address newAdmin) external onlyAdmin{
    revokeRole(DEFAULT_ADMIN_ROLE, newAdmin);
  }
  function unsetOwner(address token) external {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) || _msgSender() == owner[token], "Not admin nor owner");
    owner[token] = address(0);
  }


  function makeMeOwner(address token, uint amountForClaimers, uint _secs) external payable noOwner(token){
    owner[token] = _msgSender();
    amounts[token] = amountForClaimers;
    secs[token] = _secs;
  }

  function claim(address token) external{
    require(expiryOf[token][_msgSender()] < block.timestamp);

    IERC20(token).transfer(_msgSender(), amounts[token]);

    expiryOf[token][_msgSender()] = block.timestamp + secs[token];
  }

  function setUpToken(address token, uint _amount, uint _secs) external onlyOwner(token){
    secs[token] = _secs;
    amounts[token] = _amount;
  }

  function vaciarFaucet(address token) external onlyOwner(token){
    IERC20(token).transfer(_msgSender(), IERC20(token).balanceOf(address(this)));
  }

  receive() external payable{}
  fallback() external payable{}
  function getEther() external onlyAdmin{
    require(payable(_msgSender()).send(address(this).balance),  "Failed to send ether");
  }
  

  function getExpiryOf(address user, address token) external view returns(uint){
    uint nowTime = block.timestamp;
    return  expiryOf[token][user] > nowTime ? expiryOf[token][user] - nowTime : 0 ;
  }

  function getOwnerOf(address token) external view returns(address){
    return owner[token];
  }
  function getAmountOf(address token) external view returns(uint){
    return amounts[token];
  }
  function getSecsOf(address token) external view returns(uint){
    return secs[token];
  }
  function getEthBalance() external view returns(uint){
    return address(this).balance;
  }
}