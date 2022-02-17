pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import "@openzeppelin/contracts/utils/Counters.sol";
import './Utils.sol';

/**
 * @title HappyRobotWhitelistToken
 * HappyRobotWhitelistToken - ERC1155 contract that whitelists an operator address, has create and mint functionality, and supports useful standards from OpenZeppelin,
  like _exists(), name(), symbol(), and totalSupply()
 */
contract HappyRobotWhitelistToken is ERC1155, Ownable {
  using Counters for Counters.Counter;

  uint8  constant TOKEN_ID = 1;

  uint16 private tokenAmount = 0;

  // Contract name
  string public name;

  // Contract symbol
  string public symbol;

  address proxyRegistryAddress;

  constructor(
    string memory _uri, address _proxyRegistryAddress
  ) ERC1155(_uri) {
    name = "Happy Robot Whitelist Token";
    symbol = "HappyRobotWhitelistToken";

    proxyRegistryAddress = _proxyRegistryAddress;
  }

  /**
  * get token amount
  * @return token amount
  */
  function totalSupply() public view returns (uint16) {
    return tokenAmount;
  }

  /**
  * set token uri
  * @param _uri token uri
  */
  function setURI(string memory _uri) public onlyOwner {      
    _setURI(_uri);
  }

  /**
  * get token balance of account
  * @param _account account
  * @return token balance of account
  */
  function balanceOf(address _account) public view returns (uint256) {
    return balanceOf(_account, TOKEN_ID);
  }

  /**
   * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-free listings.
   */
  function isApprovedForAll(address _owner, address _operator) public view override returns (bool isOperator) {
    // Whitelist OpenSea proxy contract for easy trading.
    ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
    if (address(proxyRegistry.proxies(_owner)) == _operator) {
      return true;
    }

    return ERC1155.isApprovedForAll(_owner, _operator);
  }

  /**
  * mint tokens
  * @param _to address to mint
  */
  function mint(address _to) public onlyOwner {
    _mint(_to, TOKEN_ID, 1, '');
    tokenAmount++;
  }

  /**
  * burn token
  * @param _from address to burn
  */
  function burn(address _from) public onlyOwner {
    _burn(_from, TOKEN_ID, 1);
    tokenAmount--;
  }
}