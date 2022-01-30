pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import "@openzeppelin/contracts/utils/Counters.sol";
import './Utils.sol';


/**
 * @title ChlngrBrandWhitelistToken
 * ChlngrBrandWhitelistToken - ERC1155 contract that whitelists an operator address, has create and mint functionality, and supports useful standards from OpenZeppelin,
  like _exists(), name(), symbol(), and totalSupply()
 */
contract ChlngrBrandWhitelistToken is ERC1155, Ownable {
  using Counters for Counters.Counter;

  uint8  constant TOKEN_ID = 1;

  // Contract name
  string public name;

  // Contract symbol
  string public symbol;

  address proxyRegistryAddress;

  constructor(
    string memory _uri, address _proxyRegistryAddress
  ) ERC1155(_uri) {
    name = "Chlngr Brand Whitelist Token";
    symbol = "CHLNGRBRANDWHITELISTTOKEN";

    proxyRegistryAddress = _proxyRegistryAddress;
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
  * @param _account account
  * @param _amount amount
  */
  function mint(address _account, uint16 _amount) public onlyOwner {
    _mint(_account, TOKEN_ID, _amount, '');
  }
}