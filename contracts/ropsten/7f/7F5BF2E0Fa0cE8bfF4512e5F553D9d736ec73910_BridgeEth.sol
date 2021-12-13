pragma solidity ^0.8.0;

import './IERC20.sol';
import './IToken.sol';

contract BridgeEth {
  address public admin;
  IToken public token;
  uint public nonce;
  mapping(uint => bool) public processedNonces;

  enum Step { Burn, Mint }
  event EthBscTransfer(
    address from,
    address to,
    uint amount,
    uint date,
    uint nonce,
    Step indexed step
  );

  event BscEthTransfer(
    address from,
    address to,
    uint amount,
    uint date,
    uint nonce,
    Step indexed step
  );

  constructor(address tokenAddress) {
    admin = address(0xf49b13eCef3C4edd3d1C037C62455988E426aD64);
    token = IToken(tokenAddress);
  }

  function burn(address to, uint amount) external {
    token.burn(msg.sender, amount);
    emit EthBscTransfer(
      msg.sender,
      to,
      amount,
      block.timestamp,
      nonce,
      Step.Burn
    );
    nonce++;
  }

  function mint(address to, uint amount, uint otherChainNonce) external {
    require(msg.sender == admin, 'only admin');
    require(processedNonces[otherChainNonce] == false, 'transfer already processed');
    processedNonces[otherChainNonce] = true;
    token.mint(to, amount);
    emit BscEthTransfer(
      msg.sender,
      to,
      amount,
      block.timestamp,
      otherChainNonce,
      Step.Mint
    );
  }
}