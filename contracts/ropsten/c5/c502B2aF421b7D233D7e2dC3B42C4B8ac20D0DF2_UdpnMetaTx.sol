//SPDX-License-Identifier: UDPN
pragma solidity 0.8.6;

import "./lib/EIP712Base.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract UdpnMetaTx is EIP712Base {
   using SafeMath for uint256;

   address owner;
   mapping(address => uint256) private nonces;
   Token[] availableTokens;
   mapping(address => uint256) private availableTokensIndexes;
   uint256 availableTokensCount = 0;

   bytes32 private constant _TYPEHASH = keccak256(bytes("UdpnRequest(address from,address to,address token,uint256 value,uint256 fee,uint256 gas,uint256 nonce,bytes functionSignature)"));

   struct UdpnRequest {
      address from;
      address to;
      address token;
      uint256 value;
      uint256 fee;
      uint256 gas;
      uint256 nonce;
      bytes functionSignature;
   }

   struct Token {
      address contractAddress;
      string symbol;
   }

   event UdpnMetaTxExecuted(address user, address payable relayer, bytes functionSignature);

   constructor(string memory name, string memory version) EIP712Base(name, version) { 
      owner = msg.sender;
   }

   function verify(address user, UdpnRequest memory request, bytes32 sigR, bytes32 sigS, uint8 sigV) internal view returns (bool) {

      bytes32 eip712DomainHash = keccak256(
         abi.encode(
               keccak256(bytes("EIP712Domain(string name,string version,address verifyingContract,uint256 chainId)")),
               keccak256(bytes("UdpnMetaTx")),
               keccak256(bytes("0.0.1")),
               address(this),
               block.chainid
         )
      );

      bytes32 hashStruct = keccak256(
         abi.encode(
               _TYPEHASH,
               request.from,
               request.to,
               request.token,
               request.value,
               request.fee,
               request.gas,
               request.nonce,
               keccak256(request.functionSignature)
         )
      );

      bytes32 hash = keccak256(abi.encodePacked("\x19\x01", eip712DomainHash, hashStruct));
      address signer = ecrecover(hash, sigV, sigR, sigS);

      // //console.log("######> verify.signer:", signer);

      return user == signer;
   }

   function execute(
      address fromAddress, 
      address toAddress, 
      address tokenAddress,
      uint256 value,
      uint256 fee,
      uint256 gas,
      bytes memory functionSignature,
      bytes32 sigR,
      bytes32 sigS,
      uint8 sigV) public payable returns(bytes memory) {

      UdpnRequest memory request = UdpnRequest({
         nonce: nonces[fromAddress],
         from: fromAddress,
         to: toAddress,
         token: tokenAddress,
         value: value,
         fee: fee,
         gas: gas,
         functionSignature: functionSignature
      });

      require(verify(fromAddress, request, sigR, sigS, sigV));
      nonces[fromAddress] = nonces[fromAddress].add(1);

      (bool success, bytes memory returnData) = request.token.call(abi.encodePacked(request.functionSignature, request.from));

      if (!success) {
         // solhint-disable-next-line no-inline-assembly
         assembly {
         returndatacopy(0, 0, returndatasize())
         revert(0, returndatasize())
         }
      } 

      ERC20(tokenAddress).transferFrom(fromAddress, address(this), value+fee);
      ERC20(tokenAddress).transfer(toAddress, value);
 
      require(success, "UdpnMetaTx call not successful");
      emit UdpnMetaTxExecuted(fromAddress, payable(msg.sender), functionSignature);
      return returnData; 
   }

   function registerToken(string memory symbol, address contractAddress) external {

      Token memory token = Token({
         contractAddress: contractAddress,
         symbol: symbol

      });

      availableTokens.push(token);
      availableTokensIndexes[contractAddress] = availableTokensCount;
   }

   function getRegisteredToken(uint256 index) external view returns(string memory symbol,address contractAddress ){


      Token memory token = availableTokens[index];

      return (token.symbol, token.contractAddress);
   }

   function getNonce(address from) external view returns(uint256 nonce) {
      nonce = nonces[from];
   }

   function getBalance(address tokenAddress) external view returns(uint256 amount) {
      return ERC20(tokenAddress).balanceOf(address(this));
   }
}