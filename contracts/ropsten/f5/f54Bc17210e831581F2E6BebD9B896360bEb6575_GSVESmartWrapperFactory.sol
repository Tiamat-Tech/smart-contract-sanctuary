// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IGSVESmartWrapper.sol";

/**
* @dev interface to allow the burning of gas tokens from an address to save on deployment cost
*/
interface IFreeFromUpTo {
    function freeFromUpTo(address from, uint256 value) external returns (uint256 freed);
}

contract GSVESmartWrapperFactory is Ownable{
    address payable public smartWrapperLocation;
    mapping(address => uint256) private _compatibleGasTokens;
    mapping(uint256 => address) private _reverseTokenMap;
    mapping(address => address) private _deployedWalletAddressLocation;
    mapping(address => uint256) private _freeUpValue;
    address private GSVEToken;
    uint256 private _totalSupportedTokens = 0;

  constructor (address payable _smartWrapperLocation, address _GSVEToken) public {
    smartWrapperLocation = _smartWrapperLocation;
    GSVEToken = _GSVEToken;
  }

    /**
    * @dev add support for trusted gas tokens - those we wrapped
    */
    function addGasToken(address gasToken, uint256 freeUpValue) public onlyOwner{
        _compatibleGasTokens[gasToken] = 1;
        _reverseTokenMap[_totalSupportedTokens] = gasToken;
        _totalSupportedTokens = _totalSupportedTokens + 1;
        _freeUpValue[gasToken] = freeUpValue;
    }

        /**
    * @dev GSVE moddifier that burns supported gas tokens around a function that uses gas
    * the function calculates the optimal number of tokens to burn, based on the token specified
    */
    modifier discountGas(address gasToken) {
        if(gasToken != address(0)){
            require(_compatibleGasTokens[gasToken] == 1, "GSVE: incompatible token");
            uint256 gasStart = gasleft();
            _;
            uint256 gasSpent = 21000 + gasStart - gasleft() + 16 * msg.data.length;
            IFreeFromUpTo(gasToken).freeFromUpTo(msg.sender,  (gasSpent + 16000) / _freeUpValue[gasToken]);
        }
        else{
            _;
        }
    }

    /**
    * @dev return the location of a users deployed wrapper
    */
    function deployedWalletAddressLocation(address creator) public view returns(address){
        return _deployedWalletAddressLocation[creator];
    }

    /**
    * @dev function to check if a gas token is supported by the deployer
    */
    function compatibleGasToken(address gasToken) public view returns(uint256){
        return _compatibleGasTokens[gasToken];
    }

    /**
    * @dev deploys a gsve smart wrapper for the caller
    * the ownership of the wrapper is transfered to the caller
    * a note is made of where the users wrapper is deployed
    * gas tokens can be burned to save on this deployment operation
    * the gas tokens that the deployer supports are enabled in the wrapper before transfering ownership.
    */
  function deployGSVESmartWrapper(address gasToken)  public discountGas(gasToken){
        address contractAddress = Clones.clone(smartWrapperLocation);
        IGSVESmartWrapper(payable(contractAddress)).init(address(this), GSVEToken);

        for(uint256 i = 0; i<_totalSupportedTokens; i++){
            address tokenAddress = _reverseTokenMap[i];
            IGSVESmartWrapper(payable(contractAddress)).addGasToken(tokenAddress, _freeUpValue[tokenAddress]);
        }
        IGSVESmartWrapper(payable(contractAddress)).setInited();
        Ownable(contractAddress).transferOwnership(msg.sender);
        _deployedWalletAddressLocation[msg.sender] = contractAddress;
    }

}