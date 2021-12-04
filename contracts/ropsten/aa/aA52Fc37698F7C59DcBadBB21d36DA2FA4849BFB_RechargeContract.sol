/**
 *Submitted for verification at Etherscan.io on 2021-11-25
*/

// SPDX-License-Identifier: MIT
// File: contracts\open-zeppelin-contracts\token\ERC20\IERC20.sol

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract RechargeContract is Ownable,AccessControlEnumerable{
    using SafeERC20 for IERC20;
    IERC20 public contractToken;
   
    mapping (string => address) public contractTokenMap;

    address public signer1 = 0x9ba5271fB97aBbcdBd295470ab22Bb987A1876e9;
    address public signer2 = 0x43eE4A2547fF50ab3139D3A5992BDC86A65D3fDc;

    bytes32 public constant SWITCH = keccak256("SWITCH");

    bytes32 public constant MODIFYCONTRACTTOKEN = keccak256("MODIFYCONTRACTTOKEN");

    
    event AccountRecharge(address indexed from, address indexed to,address indexed contractAddress, uint256 num);
    event Withdraw(address indexed from, address indexed to,address indexed contractAddress,uint256 num,string orderId);
    
    bool withdrawSwitch = true;
    bool accountRechargeSwitch = true;

    constructor() public {
    	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(SWITCH, _msgSender());
        _setupRole(MODIFYCONTRACTTOKEN, _msgSender());
        
    }

    function grantRoles(bytes32 role, address[] calldata  account) public virtual onlyOwner() {
        for (uint256 i = 0; i < account.length; i++) {
             grantRole(role,account[i]);
         }
       
    }

     function setSig (address _signer1,address _signer2) public virtual onlyOwner(){
         signer1 = _signer1;
         signer2 = _signer2;
     }

    function modifyContractTokenMap (string memory _tokenName,address _contractTokenAddress) public virtual onlyRole(MODIFYCONTRACTTOKEN) {
    	contractTokenMap[_tokenName] = _contractTokenAddress;
    }

    function modifySwitch (bool _withdrawSwitch,bool _accountRechargeSwitch) public virtual onlyRole(SWITCH) {
    	withdrawSwitch = _withdrawSwitch;
    	accountRechargeSwitch = _accountRechargeSwitch;
    }
    
    function setContractToken(address contractAddress) public virtual onlyOwner() {
        contractToken = IERC20(contractAddress);
    
    }
 
    

    function accountRecharge(string memory _tokenName,uint256 amount) public{
		require (accountRechargeSwitch,"Not yet open");
    	require (contractTokenMap[_tokenName] != address(0),"Not yet open");
    	
        require(amount>=0, "Error:amount less zero");
		address contractTokenAddress = contractTokenMap[_tokenName];
	
        IERC20(contractTokenAddress).transferFrom(_msgSender(),address(this),  amount);

        emit AccountRecharge(_msgSender(),address(this),address(contractTokenAddress),amount);
    }


    function withdraw (string memory _tokenName,uint256 amount,string memory orderId,bytes memory signature,bytes memory signature2) public virtual  {

    	require (withdrawSwitch,"Not yet open");
    	
    	require (contractTokenMap[_tokenName] != address(0),"Not yet open");
    	address contractTokenAddress = contractTokenMap[_tokenName];
    	address withdrawAddress = _msgSender();
    	bytes32 hash1 = keccak256(
            abi.encode(address(this),withdrawAddress,contractTokenAddress,amount,orderId)
        );
        require (SignatureChecker.isValidSignatureNow(signer1,ECDSA.toEthSignedMessageHash(hash1),signature),"Signature error");
        require (SignatureChecker.isValidSignatureNow(signer2,ECDSA.toEthSignedMessageHash(hash1),signature2),"Signature error");
		 IERC20(contractTokenAddress).transfer(withdrawAddress,amount);
		 emit Withdraw(address(this),withdrawAddress,contractTokenAddress,amount,orderId);

    }
    


}