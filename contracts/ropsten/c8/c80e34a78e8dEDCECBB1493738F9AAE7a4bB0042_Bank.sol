// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/security/Pausable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";


contract Bank is Ownable, Pausable {
  address private ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
  mapping(string => address) public contractAddressERC20;

  event Deposit(address source, uint amount, string tokenName, string identifier);

  /**
  * @dev Modifier to require that 'tokenName' is not empty
  */
  modifier isToken(string memory tokenName) {
      bytes memory bytesTokenName = bytes(tokenName);
      require(bytesTokenName.length != 0, "tokenName can't be empty");
      _;
  }

  /**
  * @dev Register the contract address of an ERC20 Token
  */
  function registerTokenERC20(string memory tokenName, address tokenContractAddress) external onlyOwner isToken(tokenName) {
    require(contractAddressERC20[tokenName] == ZERO_ADDRESS, "token address is already registered");
    require(bytes(tokenName).length < 25, "token name too long");
    contractAddressERC20[tokenName] = tokenContractAddress;
  }

  /**
  * @dev Unregister the contract address of an ERC20 Token
  */
  function unRegisterTokenERC20(string memory tokenName) external onlyOwner isToken(tokenName) {
    require(contractAddressERC20[tokenName] != ZERO_ADDRESS, "token address is not registered yet");
    contractAddressERC20[tokenName] = ZERO_ADDRESS;
  }

  /**
  * @dev Transfer ERC20 token from sender address to contract address
  */
  function depositERC20Token(string memory tokenName, uint256 amount, string memory identifier) external whenNotPaused {
    require(contractAddressERC20[tokenName] != ZERO_ADDRESS, "token is not registered into the platform");
    require(IERC20(contractAddressERC20[tokenName]).allowance(msg.sender, address(this)) >= amount, "token amount to be transferred is not yet approved by User");
    IERC20(contractAddressERC20[tokenName]).transferFrom(msg.sender, address(this), amount);
    emit Deposit(msg.sender, amount, tokenName, identifier);
  }

  /**
  * @dev Transfer ERC20 token from contract address to sender address
  */
  function withdrawERC20Token(string memory tokenName, uint256 amount) external onlyOwner {
    require(contractAddressERC20[tokenName] != ZERO_ADDRESS, "token is not registered into the platform");
    IERC20(contractAddressERC20[tokenName]).transfer(msg.sender, amount);
  }

  /**
  * @dev Transfer ether from sender address to contract address
  */
  function depositEther(string memory identifier) external payable whenNotPaused {
    require(msg.value > 0, "amount must be greater than 0 ethers");
    emit Deposit(msg.sender, msg.value, "ETH", identifier);
  }

  /**
  * @dev Transfer ether token from contract address to sender address
  */
  function withdrawEther(uint256 amount) external onlyOwner {
    require(amount > 0, "amount must be greater than 0 ethers");
    payable(msg.sender).transfer(amount);
  }

  function pause() external whenNotPaused onlyOwner {
    _pause();
  }

  function unpause() external whenPaused onlyOwner {
    _unpause();
  }
}