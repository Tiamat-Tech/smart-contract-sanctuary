// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IMuonV02.sol";
import "./IMRC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

contract MRC721Bridge is AccessControl, IERC721Receiver {
  
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

  /**
   * @dev `AddToken` and `setSideContract`
   * are using this role. 
   *
   * This role could be granted another contract to let a Muon app
   * manage the tokens. The token deployer will be verified by
   * a Muon app and let the deployer add new tokens to the MTC20Bridges.
   */
  bytes32 public constant TOKEN_ADDER_ROLE = keccak256("TOKEN_ADDER");

  using ECDSA for bytes32;

  bytes4 public constant _ERC721_RECEIVED = 0x150b7a02;

  uint32 public constant APP_ID = 10;

  IMuonV02 public muon;

  // we assign a unique ID to each chain (default is CHAIN-ID)
  uint256 public network;

  // tokenId => tokenContractAddress
  mapping(uint256 => address) public tokens;
  mapping(address => uint256) public ids;

  // tokenId => isTokenMintable
  mapping(uint256 => bool) public mintable;

  event AddToken(address addr, uint256 tokenId, bool mintable);

  event Deposit(
    uint256 txId
  );

  event Claim(
    address indexed user,
    uint256 txId,
    uint256 fromChain
  );

  struct TX {
    //uint256 txId;
    uint256 tokenId;
    uint256[] nftId;
    //uint256 fromChain;
    uint256 toChain;
    address user;
  }
  uint256 public lastTxId = 0;

  mapping(uint256 => TX) public txs;
  
  // TODO: this could be calculated off-chain
  // to optimize gas fees
  mapping(address => mapping(uint256 => uint256[])) public userTxs;

  mapping(uint256 => mapping(uint256 => bool)) public claimedTxs;

  // fee in native token
  uint256 public bridgeFee = 0.001 ether;

  constructor(address _muon) {
    network = getExecutingChainID();
    muon = IMuonV02(_muon);
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function deposit(
    uint256[] calldata nftId,
    uint256 toChain,
    uint256 tokenId
  ) public payable returns (uint256) {
    require(toChain != network, 'Self Deposit');
    require(tokens[tokenId] != address(0), '!tokenId');
    require(msg.value == bridgeFee, "!value");

    IMRC721 token = IMRC721(tokens[tokenId]);
    
    if (mintable[tokenId]) {
      for (uint256 index = 0; index < nftId.length; index++) {
        token.burn(nftId[index]);
      }
    }else{
      for (uint256 index = 0; index < nftId.length; index++) {
        token.safeTransferFrom(
          address(msg.sender),
          address(this),
          nftId[index]
        );
      }
    }

    uint256 txId = ++lastTxId;
    txs[txId] = TX({
      //txId: txId,
      tokenId: tokenId,
      //fromChain: network,
      toChain: toChain,
      nftId: nftId,
      user: msg.sender
    });
    userTxs[msg.sender][toChain].push(txId);
    
    emit Deposit(txId);

    return txId;
  }


  //TODO: UI: make sure that function parameters are fine
  function claim(
    uint256[] calldata nftId,
    uint256[4] calldata txParams,
    bytes calldata _reqId,
    IMuonV02.SchnorrSign[] calldata _sigs
  ) public{
    claimFor(msg.sender, nftId, txParams, _reqId, _sigs);
  }

  function claimFor(
    address user,
    uint256[] calldata nftId,
    uint256[4] calldata txParams,
    bytes calldata _reqId,
    IMuonV02.SchnorrSign[] calldata _sigs
  ) public {

    // txParams[0] = fromChain
    // txParams[1] = toChain 
    // txParams[2] = tokenId 
    // txParams[3] = txId 

    
    // GAS optimization: this will be checked on the Muon app
    //require(sideContracts[txParams[0]] != address(0), '!sideContract');
    
    require(!claimedTxs[txParams[0]][txParams[3]], 'already claimed');
    require(txParams[1] == network, '!network');
    require(_sigs.length > 0, '!sigs');

    // split encoding to avoid "stack too deep" error.
    bytes32 hash = keccak256(
      abi.encodePacked(
        abi.encodePacked(APP_ID),
        abi.encodePacked(txParams[3], txParams[2]),
        abi.encodePacked(txParams[0], txParams[1]),
        abi.encodePacked(user),
        abi.encodePacked(nftId)
      )
    );

    require(muon.verify(_reqId, uint256(hash), _sigs), '!verified');

    IMRC721 token = IMRC721(tokens[txParams[2]]);

    if (mintable[txParams[2]]) {
      for (uint256 index = 0; index < nftId.length; index++) {
        token.mint(user, nftId[index]);
      }
    } else {
      for (uint256 index = 0; index < nftId.length; index++) {
        token.safeTransferFrom(address(this), user, nftId[index]);
      }
    }

    claimedTxs[txParams[0]][txParams[3]] = true;
    emit Claim(user, txParams[3], txParams[0]);
  }

  function pendingTxs(uint256 fromChain, uint256[] calldata _ids)
    public
    view
    returns (bool[] memory unclaimedIds)
  {
    unclaimedIds = new bool[](_ids.length);
    for (uint256 i = 0; i < _ids.length; i++) {
      unclaimedIds[i] = claimedTxs[fromChain][_ids[i]];
    }
  }

  function getUserTxs(address user, uint256 toChain)
    public
    view
    returns (uint256[] memory)
  {
    return userTxs[user][toChain];
  }

  function getTx(uint256 _txId)
    public
    view
    returns (
      uint256 txId,
      uint256 tokenId,
      uint256 fromChain,
      uint256 toChain,
      address user,
      uint256[] memory nftId
    )
  {
    txId = _txId;
    tokenId = txs[_txId].tokenId;
    fromChain = network; //txs[_txId].fromChain;
    toChain = txs[_txId].toChain;
    user = txs[_txId].user;
    nftId = txs[_txId].nftId;
  }

  function addToken(uint256 tokenId, address tokenAddress, bool _mintable)
        external
        onlyRole(TOKEN_ADDER_ROLE){

        require(ids[tokenAddress] == 0, 'already exist');

        tokens[tokenId] = tokenAddress;
        mintable[tokenId] = _mintable;

        ids[tokenAddress] = tokenId;

        emit AddToken(tokenAddress, tokenId, _mintable);
  }

  function getTokenId(address _addr) public view returns (uint256) {
    return ids[_addr];
  }

  function getExecutingChainID() public view returns (uint256) {
    uint256 id;
    assembly {
      id := chainid()
    }
    return id;
  }

  function setNetworkID(uint256 _network) public onlyRole(ADMIN_ROLE) {
    network = _network;
  }

  function setBridgeFee(uint256 _val) public onlyRole(ADMIN_ROLE){
    bridgeFee = _val;
  }

  function adminWithdrawTokens(uint256 amount,
    address _to, address tokenAddress) public onlyRole(ADMIN_ROLE) {
    require(_to != address(0));
    if(tokenAddress == address(0)){
      payable(_to).transfer(amount);  
    }else{
      IERC20(tokenAddress).transfer(_to, amount);
    }
  }

  function emergencyWithdrawERC721Tokens(
    address _tokenAddr,
    address _to,
    uint256 _id
  ) public onlyRole(ADMIN_ROLE) {
    IMRC721(_tokenAddr).safeTransferFrom(address(this), _to, _id);
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) public override returns (bytes4) {
    return _ERC721_RECEIVED;
  }
}