pragma solidity ^0.5.0;

library Strings {
  // via https://github.com/oraclize/ethereum-api/blob/master/oraclizeAPI_0.5.sol
  function strConcat(string memory _a, string memory _b, string memory _c, string memory _d, string memory _e) internal pure returns (string memory) {
      bytes memory _ba = bytes(_a);
      bytes memory _bb = bytes(_b);
      bytes memory _bc = bytes(_c);
      bytes memory _bd = bytes(_d);
      bytes memory _be = bytes(_e);
      string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
      bytes memory babcde = bytes(abcde);
      uint k = 0;
      for (uint i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
      for (uint i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
      for (uint i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
      for (uint i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];
      for (uint i = 0; i < _be.length; i++) babcde[k++] = _be[i];
      return string(babcde);
    }

    function strConcat(string memory _a, string memory _b, string memory _c, string memory _d) internal pure returns (string memory) {
        return strConcat(_a, _b, _c, _d, "");
    }

    function strConcat(string memory _a, string memory _b, string memory _c) internal pure returns (string memory) {
        return strConcat(_a, _b, _c, "", "");
    }

    function strConcat(string memory _a, string memory _b) internal pure returns (string memory) {
        return strConcat(_a, _b, "", "", "");
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }
}




pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

/**
 * @title ERC721Tradable
 * ERC721Tradable - ERC721 contract that whitelists a trading address, and has minting functionality.
 */
contract ERC721Tradable is ERC721Full, Ownable {
    using Strings for string;

    address proxyRegistryAddress;
    uint256 private _currentTokenId = 0;
    string public baseTokenURI;
    string public contractURI;
    address payable public developerAddress;
    uint256 public _developerBalance =0;
    uint256 public developerFee;




  
    

    constructor(
        string memory _name,
        string memory _symbol,
        address _proxyRegistryAddress
    ) public ERC721Full(_name, _symbol) {
        proxyRegistryAddress = _proxyRegistryAddress;
        developerAddress = msg.sender;

    }



 function withdrawDeveloperFee() public  {
     require(msg.sender == developerAddress,"You are not developer");
    developerAddress.transfer(_developerBalance);
}



 function withdrawDeveloperFeeRate(uint256 _newFee) public  {
    require(msg.sender == developerAddress,"You are not developer");
    developerFee = _newFee;
}







    /**
     * @dev Mints a token to an address with a tokenURI.
     * @param _to address of the future owner of the token
     */
    function mint(address _to) public payable {
        require(msg.value>= developerFee,"Please Pay Minimum Fee");
        _developerBalance = _developerBalance.add(msg.value);
        uint256 newTokenId = _getNextTokenId();
        _mint(_to, newTokenId);
        _incrementTokenId();
    }

    /**
     * @dev calculates the next token ID based on value of _currentTokenId
     * @return uint256 for the next token ID
     */
    function _getNextTokenId() private view returns (uint256) {
        return _currentTokenId.add(1);
    }

    /**
     * @dev increments the value of _currentTokenId
     */
    function _incrementTokenId() private {
        _currentTokenId++;
    }

  

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        return Strings.strConcat(baseTokenURI, Strings.uint2str(_tokenId));
    }

    /**
     * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        returns (bool)
    {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(owner)) == operator) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }
}






pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

/**
 * @title TrustToken
 * TrustToken - a contract for my non-fungible TrustToken.
 */
contract TrustToken is ERC721Tradable {
  

  
    constructor(address _proxyRegistryAddress)
        public
        ERC721Tradable("TrustToken", "TRST", _proxyRegistryAddress)
    {
    }

   

    function setBaseTokenURI(string memory _baseTokenURI)  public onlyOwner {
          baseTokenURI = _baseTokenURI;
    }

     function setContractURI(string memory _contractURI)  public onlyOwner {
          contractURI = _contractURI;
    }

}